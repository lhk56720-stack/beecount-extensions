package dev.beecount.extensions.automation_android

import android.content.Context
import android.util.AtomicFile
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

internal class SecureBundleStateStore(context: Context) {
    private val crypto = QueueCrypto()
    private val lock = Any()
    private val stateDirectory = File(context.noBackupFilesDir, DIRECTORY_NAME).apply {
        mkdirs()
    }
    private val atomicFile = AtomicFile(File(stateDirectory, FILE_NAME))

    fun read(): Map<String, Any?>? = synchronized(lock) {
        if (!atomicFile.baseFile.exists()) return@synchronized null
        try {
            val root = atomicFile.openRead().bufferedReader().use { reader ->
                JSONObject(reader.readText())
            }
            require(root.getInt("schemaVersion") == STORAGE_SCHEMA_VERSION)
            val cipher = root.getJSONObject("cipher")
            val plaintext = crypto.decrypt(
                EncryptedPayload(
                    iv = cipher.getString("iv"),
                    ciphertext = cipher.getString("ciphertext"),
                ),
            )
            val state = JSONObject(plaintext).toPlatformValue()
            @Suppress("UNCHECKED_CAST")
            state as Map<String, Any?>
        } catch (_: Exception) {
            atomicFile.delete()
            null
        }
    }

    fun write(state: Map<String, Any?>) = synchronized(lock) {
        val plaintext = JSONObject(state).toString()
        require(plaintext.toByteArray(Charsets.UTF_8).size <= MAX_PLAINTEXT_BYTES) {
            "local state exceeds the approved size limit"
        }
        val encrypted = crypto.encrypt(plaintext)
        val root = JSONObject()
            .put("schemaVersion", STORAGE_SCHEMA_VERSION)
            .put(
                "cipher",
                JSONObject()
                    .put("algorithm", "AES-256-GCM")
                    .put("iv", encrypted.iv)
                    .put("ciphertext", encrypted.ciphertext),
            )
        val output = atomicFile.startWrite()
        try {
            output.write(root.toString().toByteArray(Charsets.UTF_8))
            atomicFile.finishWrite(output)
        } catch (error: Exception) {
            atomicFile.failWrite(output)
            throw error
        }
    }

    fun clear() = synchronized(lock) {
        atomicFile.delete()
    }

    companion object {
        private const val STORAGE_SCHEMA_VERSION = 1
        private const val MAX_PLAINTEXT_BYTES = 1024 * 1024
        private const val DIRECTORY_NAME = "beecount_automation_state"
        private const val FILE_NAME = "bundle-state.json"
    }
}

private fun Any?.toPlatformValue(): Any? = when (this) {
    JSONObject.NULL -> null
    is JSONObject -> keys().asSequence().associateWith { key ->
        get(key).toPlatformValue()
    }
    is JSONArray -> {
        val array = this
        buildList<Any?> {
            for (index in 0 until array.length()) {
                add(array.get(index).toPlatformValue())
            }
        }
    }
    else -> this
}
