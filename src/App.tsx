import React, { useState } from 'react';
import { PlusCircle, CheckCircle2, Trash2, ClipboardList } from 'lucide-react';

interface Task {
  id: string;
  text: string;
  completed: boolean;
}

function App() {
  const [tasks, setTasks] = useState<Task[]>([]);
  const [newTask, setNewTask] = useState('');

  const addTask = (e: React.FormEvent) => {
    e.preventDefault();
    if (newTask.trim()) {
      setTasks([...tasks, { id: crypto.randomUUID(), text: newTask, completed: false }]);
      setNewTask('');
    }
  };

  const toggleTask = (id: string) => {
    setTasks(tasks.map(task => 
      task.id === id ? { ...task, completed: !task.completed } : task
    ));
  };

  const deleteTask = (id: string) => {
    setTasks(tasks.filter(task => task.id !== id));
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-purple-50 to-blue-50 py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-3xl mx-auto">
        <div className="bg-white rounded-2xl shadow-xl p-8">
          <div className="flex items-center justify-between mb-8">
            <div className="flex items-center space-x-3">
              <ClipboardList className="h-8 w-8 text-purple-600" />
              <h1 className="text-3xl font-bold text-gray-900">Task Manager</h1>
            </div>
            <div className="text-sm text-gray-500">
              {tasks.filter(t => t.completed).length}/{tasks.length} completed
            </div>
          </div>

          <form onSubmit={addTask} className="mb-8">
            <div className="flex gap-4">
              <input
                type="text"
                value={newTask}
                onChange={(e) => setNewTask(e.target.value)}
                placeholder="Add a new task..."
                className="flex-1 rounded-lg border-gray-300 shadow-sm focus:border-purple-500 focus:ring-purple-500 px-4 py-3"
              />
              <button
                type="submit"
                className="inline-flex items-center px-6 py-3 border border-transparent text-base font-medium rounded-lg shadow-sm text-white bg-purple-600 hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-purple-500"
              >
                <PlusCircle className="h-5 w-5 mr-2" />
                Add Task
              </button>
            </div>
          </form>

          <div className="space-y-4">
            {tasks.map(task => (
              <div
                key={task.id}
                className={`flex items-center justify-between p-4 rounded-lg transition-all ${
                  task.completed ? 'bg-gray-50' : 'bg-white'
                } border hover:shadow-md`}
              >
                <div className="flex items-center space-x-3">
                  <button
                    onClick={() => toggleTask(task.id)}
                    className={`rounded-full p-1 transition-colors ${
                      task.completed ? 'text-green-500 hover:text-green-600' : 'text-gray-400 hover:text-gray-500'
                    }`}
                  >
                    <CheckCircle2 className="h-6 w-6" />
                  </button>
                  <span className={`text-lg ${task.completed ? 'text-gray-500 line-through' : 'text-gray-700'}`}>
                    {task.text}
                  </span>
                </div>
                <button
                  onClick={() => deleteTask(task.id)}
                  className="text-red-400 hover:text-red-500 transition-colors"
                >
                  <Trash2 className="h-5 w-5" />
                </button>
              </div>
            ))}
            {tasks.length === 0 && (
              <div className="text-center py-12 text-gray-500">
                No tasks yet. Add one to get started!
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

export default App;