package com.flutterwallpaperplus.models

/**
 * Structured result payload sent back to Dart via MethodChannel.
 *
 * Every platform operation returns one of these instead of throwing
 * exceptions, matching the Dart-side [WallpaperResult] design.
 *
 * The [errorCode] string maps to [WallpaperErrorCode] enum values
 * on the Dart side.
 */
data class ResultPayload(
    /** Whether the operation succeeded */
    val success: Boolean,
    /** Human-readable description of the outcome */
    val message: String,
    /** Machine-readable error code matching WallpaperErrorCode.name */
    val errorCode: String = "none",
) {
    /**
     * Converts this payload to a Map for the MethodChannel response.
     *
     * Uses HashMap<String, Any> which is the type Flutter's
     * StandardMessageCodec expects.
     */
    fun toMap(): HashMap<String, Any> = hashMapOf(
        "success" to success,
        "message" to message,
        "errorCode" to errorCode,
    )

    companion object {
        /**
         * Creates a success result.
         */
        fun success(message: String): ResultPayload = ResultPayload(
            success = true,
            message = message,
            errorCode = "none",
        )

        /**
         * Creates an error result with the specified error code.
         *
         * @param message Human-readable error description.
         * @param errorCode Must match a [WallpaperErrorCode] name.
         *   Defaults to "unknown".
         */
        fun error(
            message: String,
            errorCode: String = "unknown"
        ): ResultPayload = ResultPayload(
            success = false,
            message = message,
            errorCode = errorCode,
        )
    }
}