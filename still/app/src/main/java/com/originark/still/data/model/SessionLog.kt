package com.originark.still.data.model

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "session_logs")
data class SessionLog(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val taskId: Long?,
    val taskTitle: String,
    val startedAt: Long,
    val endedAt: Long?,
    val durationSeconds: Long = 0,
    val nudgeCount: Int = 0
)
