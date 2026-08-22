package com.originark.still.data.repository

import com.originark.still.data.local.SessionLogDao
import com.originark.still.data.local.TaskDao
import com.originark.still.data.model.SessionLog
import com.originark.still.data.model.Task
import kotlinx.coroutines.flow.Flow

class StillRepository(
    private val taskDao: TaskDao,
    private val sessionLogDao: SessionLogDao
) {
    val allTasks: Flow<List<Task>> = taskDao.getAllTasks()
    val activeTask: Flow<Task?> = taskDao.getActiveTask()
    val allSessionLogs: Flow<List<SessionLog>> = sessionLogDao.getAllSessionLogs()

    suspend fun getTaskById(id: Long): Task? = taskDao.getTaskById(id)

    suspend fun insertTask(task: Task): Long = taskDao.insertTask(task)

    suspend fun updateTask(task: Task) = taskDao.updateTask(task)

    suspend fun deleteTask(task: Task) = taskDao.deleteTask(task)

    suspend fun setActiveTask(taskId: Long) = taskDao.setActiveTask(taskId)

    suspend fun clearActiveTasks() = taskDao.clearActiveTasks()

    suspend fun insertSessionLog(log: SessionLog): Long = sessionLogDao.insertSessionLog(log)

    suspend fun updateSessionLog(log: SessionLog) = sessionLogDao.updateSessionLog(log)
}
