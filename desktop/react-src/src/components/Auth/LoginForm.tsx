import React, { useState } from 'react';
import { useApp } from '../../context/AppContext';

//! форма логина и регистрации
export const LoginForm: React.FC = () => {
  const { login, register, error } = useApp();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [mode, setMode] = useState<'login' | 'register'>('login');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email || !password) return;

    setIsLoading(true);
    try {
      if (mode === 'login') {
        await login(email, password);
      } else {
        await register(email, password);
      }
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="flex items-center justify-center h-screen bg-dark-900">
      <div className="bg-dark-800 p-8 rounded-lg border border-dark-500 shadow-lg w-full max-w-md">
        <h2 className="text-2xl font-bold mb-6 text-center text-dark-200">
          {mode === 'login' ? 'Login to ZetGui' : 'Register for ZetGui'}
        </h2>

        {error && (
          <div className="bg-red-900/20 border border-red-800 text-red-200 px-4 py-3 rounded mb-4">
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit}>
          <div className="mb-4">
            <label htmlFor="email" className="block text-dark-300 mb-2">Email</label>
            <input
              id="email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full bg-dark-700 border border-dark-500 rounded-sm px-3 py-2 text-dark-200 focus:outline-none focus:ring-2 focus:ring-accent"
              required
            />
          </div>

          <div className="mb-6">
            <label htmlFor="password" className="block text-dark-300 mb-2">Password</label>
            <input
              id="password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full bg-dark-700 border border-dark-500 rounded-sm px-3 py-2 text-dark-200 focus:outline-none focus:ring-2 focus:ring-accent"
              required
            />
          </div>

          <button
            type="submit"
            disabled={isLoading}
            className="w-full bg-accent hover:bg-accent-dark text-dark-200 font-bold py-2 px-4 rounded-sm focus:outline-none focus:ring-2 focus:ring-accent transition-colors disabled:opacity-50"
          >
            {isLoading
              ? (mode === 'login' ? 'Logging in...' : 'Registering...')
              : (mode === 'login' ? 'Login' : 'Register')
            }
          </button>
        </form>

        <div className="mt-4 text-center">
          <button
            type="button"
            onClick={() => setMode(mode === 'login' ? 'register' : 'login')}
            className="text-accent hover:text-accent-dark transition-colors"
            disabled={isLoading}
          >
            {mode === 'login'
              ? "Don't have an account? Register"
              : "Already have an account? Login"
            }
          </button>
        </div>
      </div>
    </div>
  );
}; 