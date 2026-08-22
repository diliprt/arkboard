package com.originark.still.data.local

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.originark.still.data.model.SessionLog
import kotlinx.coroutines.flow.Flow

@Dao
interface SessionLogDao {
    @Query("SELECT * FROM session_logs ORDER BY startedAt DESC")
    fun getAllSessionLogs(): Flow<List<SessionLog>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertSessionLog(log: SessionLog): Long

    @Update
    suspend fun updateSessionLog(log: SessionLog)
}
