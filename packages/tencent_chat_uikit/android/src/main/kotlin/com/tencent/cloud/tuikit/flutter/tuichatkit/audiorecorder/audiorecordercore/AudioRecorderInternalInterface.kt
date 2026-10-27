package com.tencent.cloud.tuikit.flutter.tuichatkit.audiorecorder.audiorecordercore
import com.tencent.cloud.tuikit.flutter.tuichatkit.audiorecorder.audiorecorderimpl.RecorderListener

interface AudioRecorderInternalInterface {
    fun setListener(listener: RecorderListener?)
    fun startRecord(filePath: String? = null, minRecordDurationMs: Int, maxRecordDurationMs: Int)
    fun stopRecord()
    fun enableAIDeNoise(enable: Boolean)
}