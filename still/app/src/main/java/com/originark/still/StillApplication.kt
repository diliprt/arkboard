package com.originark.still

import android.app.Application
import com.originark.still.data.local.StillDatabase
import com.originark.still.data.repository.StillRepository

class StillApplication : Application() {
    val database by lazy { StillDatabase.getDatabase(this) }
    val repository by lazy { StillRepository(database.taskDao(), database.sessionLogDao()) }

    override fun onCreate() {
        super.onCreate()
    }
}
