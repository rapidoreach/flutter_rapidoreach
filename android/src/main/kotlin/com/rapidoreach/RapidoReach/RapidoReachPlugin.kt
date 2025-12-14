package com.rapidoreach.RapidoReach

import android.app.Activity
import android.net.Uri
import androidx.annotation.NonNull
import com.rapidoreach.rapidoreachsdk.RapidoReach
import com.rapidoreach.rapidoreachsdk.RapidoReachSurveyAvailableListener
import com.rapidoreach.rapidoreachsdk.RapidoReachSdk
import com.rapidoreach.rapidoreachsdk.RrContentEvent
import com.rapidoreach.rapidoreachsdk.RrContentEventType
import com.rapidoreach.rapidoreachsdk.RrError
import com.rapidoreach.rapidoreachsdk.RrInitOptions
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import org.json.JSONArray
import org.json.JSONObject

class RapidoReachPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
  private lateinit var channel: MethodChannel
  private var activity: Activity? = null

  private var networkLoggingEnabled: Boolean = false
  private var configuredApiKey: String? = null
  private var configuredUserId: String? = null
  private var sdkInitialized: Boolean = false
  private var initInProgress: Boolean = false

  private var navBarColor: String? = null
  private var navBarTextColor: String? = null
  private var navBarText: String? = null
  private var apiEndpoint: String? = null

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "rapidoreach")
    channel.setMethodCallHandler(this)
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivity() {
    activity = null
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    try {
      when (call.method) {
        "init" -> init(call, result)
        "setUserIdentifier" -> setUserIdentifier(call, result)
        "show" -> show(call, result)
        "showRewardCenter" -> showRewardCenter(result)
        "isSurveyAvailable" -> isSurveyAvailable(result)
        "setNavBarText" -> setNavBarText(call, result)
        "setNavBarColor" -> setNavBarColor(call, result)
        "setNavBarTextColor" -> setNavBarTextColor(call, result)
        "enableNetworkLogging" -> enableNetworkLogging(call, result)
        "getBaseUrl" -> getBaseUrl(result)
        "updateBackend" -> updateBackend(call, result)
        "sendUserAttributes" -> sendUserAttributes(call, result)
        "getPlacementDetails" -> getPlacementDetails(call, result)
        "listSurveys" -> listSurveys(call, result)
        "hasSurveys" -> hasSurveys(call, result)
        "canShowContent" -> canShowContent(call, result)
        "canShowSurvey" -> canShowSurvey(call, result)
        "showSurvey" -> showSurvey(call, result)
        "fetchQuickQuestions" -> fetchQuickQuestions(call, result)
        "hasQuickQuestions" -> hasQuickQuestions(call, result)
        "answerQuickQuestion" -> answerQuickQuestion(call, result)
        else -> result.notImplemented()
      }
    } catch (t: Throwable) {
      result.error("unexpected_error", t.message ?: t.toString(), mapOf("method" to call.method))
    }
  }

  private fun requireInitialized(result: Result, method: String): Boolean {
    if (sdkInitialized) return true
    result.error(
      "not_initialized",
      "RapidoReach not initialized. Call RapidoReach.instance.init(apiToken: ..., userId: ...) and await it before calling `$method`.",
      mapOf("method" to method)
    )
    return false
  }

  private fun requireActivity(result: Result, method: String): Activity? {
    val current = activity
    if (current != null) return current
    result.error(
      "no_activity",
      "RapidoReach requires a foreground Activity. Call `$method` from a UI-attached Flutter engine (not from a background isolate).",
      mapOf("method" to method)
    )
    return null
  }

  private fun init(call: MethodCall, result: Result) {
    val currentActivity = requireActivity(result, "init") ?: return

    val apiKey = call.argument<String>("api_token")?.trim()
    val userId = call.argument<String>("user_id")?.trim()
    if (apiKey.isNullOrEmpty()) {
      result.error("no_api_token", "api_token is required", null)
      return
    }
    if (userId.isNullOrEmpty()) {
      result.error("no_user_id", "user_id is required", null)
      return
    }

    if (initInProgress) {
      result.error("init_in_progress", "RapidoReach initialization is already in progress.", null)
      return
    }

    if (sdkInitialized) {
      if (configuredApiKey != null && configuredApiKey != apiKey) {
        result.error(
          "already_initialized",
          "RapidoReach is already initialized with a different api_token. Restart the app to reinitialize.",
          null
        )
        return
      }

      configuredApiKey = apiKey
      if (configuredUserId != userId) {
        configuredUserId = userId
        RapidoReachSdk.setUserIdentifier(userId) { err ->
          if (err != null) {
            result.error("set_user_id_error", err.description ?: err.code, null)
          } else {
            result.success(null)
          }
        }
      } else {
        result.success(null)
      }
      return
    }

    configuredApiKey = apiKey
    configuredUserId = userId

    val options = RrInitOptions(
      navigationBarColor = navBarColor,
      navigationBarTextColor = navBarTextColor,
      navigationBarText = navBarText,
      placementId = null,
      resetProfiler = false,
      clearPreviousAttributes = false
    )

    var settled = false
    initInProgress = true
    RapidoReachSdk.initialize(
      apiToken = apiKey,
      userIdentifier = userId,
      context = currentActivity,
      rewardCallback = { rewards ->
        val total = rewards.sumOf { it.rewardAmount }
        sendEvent("onReward", total)
      },
      errorCallback = { error ->
        sdkInitialized = false
        initInProgress = false
        sendEvent("onError", error.description ?: error.code)
        emitNetworkLog(
          name = "initialize",
          method = "INIT",
          url = null,
          error = error.description ?: error.code
        )
        if (!settled) {
          settled = true
          result.error("init_error", error.description ?: error.code, null)
        }
      },
      sdkReadyCallback = {
        sdkInitialized = true
        initInProgress = false
        apiEndpoint?.let {
          try {
            RapidoReach.getInstance().setApiEndpoint(it)
          } catch (_: Exception) {
          }
        }
        emitNetworkLog(
          name = "initialize",
          method = "INIT",
          url = null,
          responseBody = mapOf("status" to "initialized")
        )
        if (!settled) {
          settled = true
          result.success(null)
        }
      },
      contentCallback = { contentEvent ->
        handleContentEvent(contentEvent)
      },
      initOptions = options
    )

    RapidoReach.getInstance().setRapidoReachSurveyAvailableListener(object :
      RapidoReachSurveyAvailableListener {
      override fun rapidoReachSurveyAvailable(surveyAvailable: Boolean) {
        val value = if (surveyAvailable) 1 else 0
        sendEvent("rapidoReachSurveyAvailable", value)
        sendEvent("rapidoreachSurveyAvailable", value)
      }
    })
  }

  private fun setUserIdentifier(call: MethodCall, result: Result) {
    val userId = call.argument<String>("user_id")?.trim()
    if (userId.isNullOrEmpty()) {
      result.error("no_user_id", "user_id is required", null)
      return
    }
    configuredUserId = userId
    if (!requireInitialized(result, "setUserIdentifier")) return
    RapidoReachSdk.setUserIdentifier(userId) { error: RrError? ->
      if (error != null) {
        result.error(error.code, error.description ?: error.code, null)
      } else {
        result.success(null)
      }
    }
  }

  private fun show(call: MethodCall, result: Result) {
    requireActivity(result, "show") ?: return
    if (!requireInitialized(result, "show")) return
    val placement = call.argument<String>("placementID")?.trim()
    try {
      if (!placement.isNullOrEmpty()) {
        RapidoReach.getInstance().showRewardCenter(placement)
      } else {
        RapidoReach.getInstance().showRewardCenter()
      }
      result.success(null)
    } catch (e: Exception) {
      result.error("show_failed", e.message, null)
    }
  }

  private fun showRewardCenter(result: Result) {
    requireActivity(result, "showRewardCenter") ?: return
    if (!requireInitialized(result, "showRewardCenter")) return
    try {
      RapidoReach.getInstance().showRewardCenter()
      result.success(null)
    } catch (e: Exception) {
      result.error("show_failed", e.message, null)
    }
  }

  private fun isSurveyAvailable(result: Result) {
    if (!requireInitialized(result, "isSurveyAvailable")) return
    try {
      result.success(RapidoReach.getInstance().isSurveyAvailable())
    } catch (e: Exception) {
      result.error("is_survey_available_error", e.message, null)
    }
  }

  private fun setNavBarText(call: MethodCall, result: Result) {
    val text = call.argument<String>("text")
    navBarText = text
    try {
      if (sdkInitialized) {
        RapidoReach.getInstance().setNavigationBarText(text)
      }
      result.success(null)
    } catch (e: Exception) {
      result.error("set_navbar_text_error", e.message, null)
    }
  }

  private fun setNavBarColor(call: MethodCall, result: Result) {
    val color = call.argument<String>("color")
    navBarColor = color
    try {
      if (sdkInitialized) {
        RapidoReach.getInstance().setNavigationBarColor(color)
      }
      result.success(null)
    } catch (e: Exception) {
      result.error("set_navbar_color_error", e.message, null)
    }
  }

  private fun setNavBarTextColor(call: MethodCall, result: Result) {
    val textColor = call.argument<String>("text_color")
    navBarTextColor = textColor
    try {
      if (sdkInitialized) {
        RapidoReach.getInstance().setNavigationBarTextColor(textColor)
      }
      result.success(null)
    } catch (e: Exception) {
      result.error("set_navbar_text_color_error", e.message, null)
    }
  }

  private fun enableNetworkLogging(call: MethodCall, result: Result) {
    val enabled = call.argument<Boolean>("enabled") ?: false
    networkLoggingEnabled = enabled
    result.success(null)
  }

  private fun getBaseUrl(result: Result) {
    try {
      result.success(RapidoReach.getProxyBaseUrl())
    } catch (e: Exception) {
      result.error("get_base_url_error", e.message, null)
    }
  }

  private fun updateBackend(call: MethodCall, result: Result) {
    val baseUrl = call.argument<String>("baseURL")?.trim()
    if (baseUrl.isNullOrEmpty()) {
      result.error("invalid_args", "baseURL is required", null)
      return
    }
    apiEndpoint = baseUrl
    try {
      if (sdkInitialized) {
        RapidoReach.getInstance().setApiEndpoint(baseUrl)
      }
      emitNetworkLog(name = "updateBackend", method = "CONFIG", url = baseUrl)
      result.success(null)
    } catch (e: Exception) {
      emitNetworkLog(name = "updateBackend", method = "CONFIG", url = baseUrl, error = e.message ?: e.toString())
      result.error("update_backend_error", e.message, null)
    }
  }

  private fun sendUserAttributes(call: MethodCall, result: Result) {
    if (!requireInitialized(result, "sendUserAttributes")) return
    val attributes = call.argument<Map<String, Any?>>("attributes") ?: emptyMap()
    val clearPrevious = call.argument<Boolean>("clear_previous") ?: false
    val safeAttributes: Map<String, Any> =
      attributes.filterValues { it != null }.mapValues { it.value as Any }

    val url = buildUrl("/api/sdk/v2/user_attributes", includeAuthQuery = false)
    val requestBody = mutableMapOf<String, Any>(
      "attributes" to safeAttributes,
      "clear_previous" to clearPrevious
    )
    configuredApiKey?.let { requestBody["api_key"] = it }
    configuredUserId?.let { requestBody["sdk_user_id"] = it }

    RapidoReachSdk.sendUserAttributes(safeAttributes, clearPrevious) { err ->
      if (err != null) {
        emitNetworkLog(
          name = "sendUserAttributes",
          method = "POST",
          url = url,
          requestBody = requestBody,
          error = err.description ?: err.code
        )
        result.error("send_user_attributes_error", err.description ?: err.code, null)
      } else {
        emitNetworkLog(
          name = "sendUserAttributes",
          method = "POST",
          url = url,
          requestBody = requestBody,
          responseBody = mapOf("status" to "success")
        )
        result.success(null)
      }
    }
  }

  private fun getPlacementDetails(call: MethodCall, result: Result) {
    if (!requireInitialized(result, "getPlacementDetails")) return
    val tag = call.argument<String>("tag")?.trim()
    if (tag.isNullOrEmpty()) {
      result.error("invalid_args", "tag is required", null)
      return
    }
    val url = buildUrl("/api/sdk/v2/placements/$tag/details", includeAuthQuery = true)
    RapidoReachSdk.getPlacementDetails(tag) { sdkResult ->
      sdkResult.fold(
        onSuccess = { details ->
          val payload = mutableMapOf<String, Any?>()
          details.name?.let { payload["name"] = it }
          details.contentType?.let { payload["contentType"] = it }
          details.currencyName?.let { payload["currencyName"] = it }
          details.isSale?.let { payload["isSale"] = it }
          details.saleType?.let { payload["saleType"] = it }
          details.saleEndDate?.let { payload["saleEndDate"] = it }
          details.saleMultiplier?.let { payload["saleMultiplier"] = it }
          details.saleDisplayName?.let { payload["saleDisplayName"] = it }
          details.saleTag?.let { payload["saleTag"] = it }
          details.isHot?.let { payload["isHot"] = it }
          emitNetworkLog(name = "getPlacementDetails", method = "GET", url = url, responseBody = payload)
          result.success(payload)
        },
        onFailure = { error ->
          emitNetworkLog(name = "getPlacementDetails", method = "GET", url = url, error = error.message ?: error.toString())
          result.error("placement_details_error", error.message, null)
        }
      )
    }
  }

  private fun listSurveys(call: MethodCall, result: Result) {
    if (!requireInitialized(result, "listSurveys")) return
    val tag = call.argument<String>("tag")?.trim()
    if (tag.isNullOrEmpty()) {
      result.error("invalid_args", "tag is required", null)
      return
    }
    val url = buildUrl("/api/sdk/v2/placements/$tag/surveys", includeAuthQuery = true)
    RapidoReachSdk.listSurveys(tag) { sdkResult ->
      sdkResult.fold(
        onSuccess = { surveys ->
          val list = surveys.map { s ->
            mutableMapOf<String, Any?>(
              "surveyIdentifier" to s.surveyIdentifier,
              "lengthInMinutes" to s.lengthInMinutes,
              "rewardAmount" to s.rewardAmount,
              "isHotTile" to s.isHotTile,
              "isSale" to s.isSale,
            ).apply {
              s.currencyName?.let { this["currencyName"] = it }
              s.saleMultiplier?.let { this["saleMultiplier"] = it }
              s.saleEndDate?.let { this["saleEndDate"] = it }
              s.preSaleRewardAmount?.let { this["preSaleRewardAmount"] = it }
              s.provider?.let { this["provider"] = it }
            }
          }
          emitNetworkLog(name = "listSurveys", method = "GET", url = url, responseBody = list)
          result.success(list)
        },
        onFailure = { error ->
          emitNetworkLog(name = "listSurveys", method = "GET", url = url, error = error.message ?: error.toString())
          result.error("list_surveys_error", error.message, null)
        }
      )
    }
  }

  private fun hasSurveys(call: MethodCall, result: Result) {
    if (!requireInitialized(result, "hasSurveys")) return
    val tag = call.argument<String>("tag")?.trim()
    if (tag.isNullOrEmpty()) {
      result.error("invalid_args", "tag is required", null)
      return
    }
    val url = buildUrl("/api/sdk/v2/placements/$tag/surveys", includeAuthQuery = true)
    RapidoReachSdk.hasSurveys(tag) { sdkResult ->
      sdkResult.fold(
        onSuccess = { available ->
          emitNetworkLog(name = "hasSurveys", method = "GET", url = url, responseBody = mapOf("hasSurveys" to available))
          result.success(available)
        },
        onFailure = { error ->
          emitNetworkLog(name = "hasSurveys", method = "GET", url = url, error = error.message ?: error.toString())
          result.error("has_surveys_error", error.message, null)
        }
      )
    }
  }

  private fun canShowContent(call: MethodCall, result: Result) {
    if (!requireInitialized(result, "canShowContent")) return
    val tag = call.argument<String>("tag")?.trim()
    if (tag.isNullOrEmpty()) {
      result.error("invalid_args", "tag is required", null)
      return
    }
    val url = buildUrl("/api/sdk/v2/placements/$tag/can_show", includeAuthQuery = true)
    var settled = false
    val canShow = RapidoReachSdk.canShowContentForPlacement(tag) { error ->
      if (!settled) {
        settled = true
        emitNetworkLog(name = "canShowContent", method = "GET", url = url, error = error.description ?: error.code)
        result.error(error.code, error.description ?: error.code, null)
      }
    }
    if (!settled) {
      settled = true
      emitNetworkLog(name = "canShowContent", method = "GET", url = url, responseBody = mapOf("canShow" to canShow))
      result.success(canShow)
    }
  }

  private fun canShowSurvey(call: MethodCall, result: Result) {
    if (!requireInitialized(result, "canShowSurvey")) return
    val tag = call.argument<String>("tag")?.trim()
    val surveyId = call.argument<String>("surveyId")?.trim()
    if (tag.isNullOrEmpty() || surveyId.isNullOrEmpty()) {
      result.error("invalid_args", "tag and surveyId are required", null)
      return
    }
    val url = buildUrl("/api/sdk/v2/placements/$tag/surveys/$surveyId/can_show", includeAuthQuery = true)
    RapidoReachSdk.canShowSurvey(tag, surveyId) { sdkResult ->
      sdkResult.fold(
        onSuccess = { canShow ->
          emitNetworkLog(name = "canShowSurvey", method = "GET", url = url, responseBody = mapOf("canShow" to canShow))
          result.success(canShow)
        },
        onFailure = { error ->
          emitNetworkLog(name = "canShowSurvey", method = "GET", url = url, error = error.message ?: error.toString())
          result.error("can_show_survey_error", error.message, null)
        }
      )
    }
  }

  private fun showSurvey(call: MethodCall, result: Result) {
    requireActivity(result, "showSurvey") ?: return
    if (!requireInitialized(result, "showSurvey")) return
    val tag = call.argument<String>("tag")?.trim()
    val surveyId = call.argument<String>("surveyId")?.trim()
    val customParamsRaw = call.argument<Map<String, Any?>>("customParams")?.filterValues { it != null }
    val customParams = customParamsRaw?.mapValues { it.value as Any }
    if (tag.isNullOrEmpty() || surveyId.isNullOrEmpty()) {
      result.error("invalid_args", "tag and surveyId are required", null)
      return
    }

    val url = buildUrl("/api/sdk/v2/placements/$tag/surveys/$surveyId/show", includeAuthQuery = false)
    val requestBody = mutableMapOf<String, Any?>("custom_params" to customParams).filterValues { it != null }.toMutableMap()
    configuredApiKey?.let { requestBody["api_key"] = it }
    configuredUserId?.let { requestBody["sdk_user_id"] = it }

    emitNetworkLog(name = "showSurvey", method = "POST", url = url, requestBody = requestBody)

    var resolved = false
    RapidoReachSdk.showSurvey(
      tag = tag,
      surveyId = surveyId,
      customParameters = customParams,
      contentListener = { contentEvent ->
        handleContentEvent(contentEvent)
        if (contentEvent.type == RrContentEventType.SHOWN && !resolved) {
          resolved = true
          result.success(null)
        }
      },
      errorListener = { err ->
        if (!resolved) {
          resolved = true
          emitNetworkLog(name = "showSurvey", method = "POST", url = url, requestBody = requestBody, error = err.description ?: err.code)
          result.error(err.code, err.description ?: err.code, null)
        }
      }
    )
  }

  private fun fetchQuickQuestions(call: MethodCall, result: Result) {
    if (!requireInitialized(result, "fetchQuickQuestions")) return
    val tag = call.argument<String>("tag")?.trim()
    if (tag.isNullOrEmpty()) {
      result.error("invalid_args", "tag is required", null)
      return
    }
    val url = buildUrl("/api/sdk/v2/placements/$tag/quick_questions", includeAuthQuery = true)
    RapidoReachSdk.fetchQuickQuestions(tag) { sdkResult ->
      sdkResult.fold(
        onSuccess = { payload ->
          emitNetworkLog(name = "fetchQuickQuestions", method = "GET", url = url, responseBody = payload.data)
          result.success(payload.data)
        },
        onFailure = { error ->
          emitNetworkLog(name = "fetchQuickQuestions", method = "GET", url = url, error = error.message ?: error.toString())
          result.error("fetch_quick_questions_error", error.message, null)
        }
      )
    }
  }

  private fun hasQuickQuestions(call: MethodCall, result: Result) {
    if (!requireInitialized(result, "hasQuickQuestions")) return
    val tag = call.argument<String>("tag")?.trim()
    if (tag.isNullOrEmpty()) {
      result.error("invalid_args", "tag is required", null)
      return
    }
    fetchQuickQuestions(call, object : Result {
      override fun success(value: Any?) {
        val payload = value as? Map<*, *> ?: emptyMap<String, Any?>()
        val enabled = payload["enabled"] as? Boolean ?: false
        val questions = payload["quick_questions"] as? List<*> ?: emptyList<Any?>()
        result.success(enabled && questions.isNotEmpty())
      }

      override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
        result.error(errorCode, errorMessage, errorDetails)
      }

      override fun notImplemented() {
        result.notImplemented()
      }
    })
  }

  private fun answerQuickQuestion(call: MethodCall, result: Result) {
    if (!requireInitialized(result, "answerQuickQuestion")) return
    val tag = call.argument<String>("tag")?.trim()
    val questionId = call.argument<String>("questionId")?.trim()
    val answer = call.argument<Any>("answer")
    if (tag.isNullOrEmpty() || questionId.isNullOrEmpty() || answer == null) {
      result.error("invalid_args", "tag, questionId, and answer are required", null)
      return
    }
    val url = buildUrl("/api/sdk/v2/placements/$tag/quick_questions/$questionId/answer", includeAuthQuery = false)
    val requestBody = mutableMapOf<String, Any?>("answer" to answer)
    configuredApiKey?.let { requestBody["api_key"] = it }
    configuredUserId?.let { requestBody["sdk_user_id"] = it }

    RapidoReachSdk.answerQuickQuestion(tag, questionId, answer) { sdkResult ->
      sdkResult.fold(
        onSuccess = { payload ->
          emitNetworkLog(name = "answerQuickQuestion", method = "POST", url = url, requestBody = requestBody, responseBody = payload.data)
          result.success(payload.data)
        },
        onFailure = { error ->
          emitNetworkLog(name = "answerQuickQuestion", method = "POST", url = url, requestBody = requestBody, error = error.message ?: error.toString())
          result.error("answer_quick_question_error", error.message, null)
        }
      )
    }
  }

  private fun handleContentEvent(contentEvent: RrContentEvent) {
    when (contentEvent.type) {
      RrContentEventType.SHOWN -> sendEvent("onRewardCenterOpened", 0)
      RrContentEventType.DISMISSED -> sendEvent("onRewardCenterClosed", 0)
    }
  }

  private fun sendEvent(method: String, args: Any?) {
    activity?.runOnUiThread {
      channel.invokeMethod(method, args)
    }
  }

  private fun stringifyForLog(value: Any?): String? {
    if (value == null) return null
    return try {
      when (value) {
        is String -> value
        is Map<*, *> -> JSONObject(value).toString()
        is List<*> -> JSONArray(value).toString()
        else -> value.toString()
      }
    } catch (_: Exception) {
      value.toString()
    }
  }

  private fun buildUrl(path: String, includeAuthQuery: Boolean): String {
    val base = RapidoReach.getProxyBaseUrl().trimEnd('/')
    val normalized = if (path.startsWith("/")) path else "/$path"
    val builder = Uri.parse(base + normalized).buildUpon()
    if (includeAuthQuery) {
      configuredApiKey?.let { builder.appendQueryParameter("api_key", it) }
      configuredUserId?.let { builder.appendQueryParameter("sdk_user_id", it) }
    }
    return builder.build().toString()
  }

  private fun emitNetworkLog(
    name: String,
    method: String,
    url: String?,
    requestBody: Any? = null,
    responseBody: Any? = null,
    error: String? = null
  ) {
    if (!networkLoggingEnabled) return

    val payload = mutableMapOf<String, Any?>(
      "name" to name,
      "method" to method,
      "timestampMs" to System.currentTimeMillis(),
    )
    if (url != null) payload["url"] = url
    stringifyForLog(requestBody)?.let { payload["requestBody"] = it }
    stringifyForLog(responseBody)?.let { payload["responseBody"] = it }
    if (error != null) payload["error"] = error

    sendEvent("rapidoreachNetworkLog", payload)
  }
}
