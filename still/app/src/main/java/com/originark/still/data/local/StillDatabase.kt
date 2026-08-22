package com.originark.still.data.local

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import com.originark.still.data.model.SessionLog
import com.originark.still.data.model.Task

@Database(entities = [Task::class, SessionLog::class], version = 1, exportSchema = false)
abstract class StillDatabase : RoomDatabase() {
    abstract fun taskDao(): TaskDao
    abstract fun sessionLogDao(): SessionLogDao

    companion object {
        @Volatile
        private var INSTANCE: StillDatabase? = null

        fun getDatabase(context: Context): StillDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    StillDatabase::class.java,
                    "still_database"
                ).build()
                INSTANCE = instance
                instance
            }
        }
    }
}
