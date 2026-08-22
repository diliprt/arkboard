package com.originark.still

import com.originark.still.data.local.SessionLogDao
import com.originark.still.data.local.TaskDao
import com.originark.still.data.model.SessionLog
import com.originark.still.data.model.Task
import com.originark.still.data.repository.StillRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class FakeTaskDao : TaskDao {
    private val tasks = mutableListOf<Task>()
    private val tasksFlow = MutableStateFlow<List<Task>>(emptyList())
    private val activeTaskFlow = MutableStateFlow<Task?>(null)

    private fun updateFlows() {
        tasksFlow.value = tasks.sortedWith(compareByDescending<Task> { it.isActive }.thenByDescending { it.createdAt })
        activeTaskFlow.value = tasks.firstOrNull { it.isActive }
    }

    override fun getAllTasks(): Flow<List<Task>> = tasksFlow
    override fun getActiveTask(): Flow<Task?> = activeTaskFlow

    override suspend fun getTaskById(id: Long): Task? = tasks.firstOrNull { it.id == id }

    override suspend fun insertTask(task: Task): Long {
        val id = if (task.id == 0L) (tasks.size + 1).toLong() else task.id
        val newTask = task.copy(id = id)
        tasks.removeAll { it.id == id }
        tasks.add(newTask)
        updateFlows()
        return id
    }

    override suspend fun updateTask(task: Task) {
        tasks.removeAll { it.id == task.id }
        tasks.add(task)
        updateFlows()
    }

    override suspend fun deleteTask(task: Task) {
        tasks.removeAll { it.id == task.id }
        updateFlows()
    }

    override suspend fun clearActiveTasks() {
        for (i in tasks.indices) {
            tasks[i] = tasks[i].copy(isActive = false)
        }
        updateFlows()
    }

    override suspend fun setActiveTask(taskId: Long) {
        for (i in tasks.indices) {
            tasks[i] = tasks[i].copy(isActive = (tasks[i].id == taskId))
        }
        updateFlows()
    }
}

class FakeSessionLogDao : SessionLogDao {
    private val logs = mutableListOf<SessionLog>()
    private val logsFlow = MutableStateFlow<List<SessionLog>>(emptyList())

    override fun getAllSessionLogs(): Flow<List<SessionLog>> = logsFlow

    override suspend fun insertSessionLog(log: SessionLog): Long {
        val id = if (log.id == 0L) (logs.size + 1).toLong() else log.id
        val newLog = log.copy(id = id)
        logs.add(newLog)
        logsFlow.value = logs.sortedByDescending { it.startedAt }
        return id
    }

    override suspend fun updateSessionLog(log: SessionLog) {
        logs.removeAll { it.id == log.id }
        logs.add(log)
        logsFlow.value = logs.sortedByDescending { it.startedAt }
    }
}

class StillRepositoryTest {
    private lateinit var taskDao: FakeTaskDao
    private lateinit var sessionLogDao: FakeSessionLogDao
    private lateinit var repository: StillRepository

    @Before
    fun setup() {
        taskDao = FakeTaskDao()
        sessionLogDao = FakeSessionLogDao()
        repository = StillRepository(taskDao, sessionLogDao)
    }

    @Test
    fun testInsertAndRetrieveTask() = runBlocking {
        val taskId = repository.insertTask(Task(title = "Deep work on Still architecture"))
        val retrieved = repository.getTaskById(taskId)
        assertNotNull(retrieved)
        assertEquals("Deep work on Still architecture", retrieved?.title)
        assertFalse(retrieved!!.isCompleted)
    }

    @Test
    fun testSetActiveTask() = runBlocking {
        val id1 = repository.insertTask(Task(title = "Task 1"))
        val id2 = repository.insertTask(Task(title = "Task 2"))

        repository.setActiveTask(id2)
        val active = repository.activeTask.first()
        assertEquals(id2, active?.id)
        assertTrue(active!!.isActive)

        repository.clearActiveTasks()
        val noneActive = repository.activeTask.first()
        assertNull(noneActive)
    }
}
