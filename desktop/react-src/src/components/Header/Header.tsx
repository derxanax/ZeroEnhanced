import React, { useState, useEffect } from 'react';

interface UserInfo {
  email: string;
  request_count: number;
}

export const Header: React.FC = () => {
  const [userInfo, setUserInfo] = useState<UserInfo | null>(null);
  const [isMenuOpen, setIsMenuOpen] = useState(false);

  useEffect(() => {
    fetchUserInfo();
  }, []);

  const fetchUserInfo = async () => {
    try {
      const token = localStorage.getItem('auth_token');
      if (!token) return;

      const response = await fetch('/api/user/me', {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      
      if (response.ok) {
        const data = await response.json();
        setUserInfo(data);
      }
    } catch (error) {
      console.error('Failed to fetch user info:', error);
    }
  };

  const handleLogout = () => {
    localStorage.removeItem('auth_token');
    window.location.reload();
  };

  return (
    <header className="flex items-center justify-between px-6 py-3 bg-gray-800 border-b border-gray-700">
      {/* Left side - Logo and title */}
      <div className="flex items-center space-x-4">
        <div className="flex items-center">   
          <svg className="w-8 h-8 text-blue-500" fill="currentColor" viewBox="0 0 20 20">
            <path fillRule="evenodd" d="M3 3a1 1 0 000 2v8a2 2 0 002 2h2.586l-1.293 1.293a1 1 0 101.414 1.414L10 15.414l2.293 2.293a1 1 0 001.414-1.414L12.414 15H15a2 2 0 002-2V5a1 1 0 100-2H3zm11.707 4.707a1 1 0 00-1.414-1.414L10 9.586 8.707 8.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
          </svg>
          <span className="ml-2 text-xl font-bold text-white">ZetGui</span>
        </div>
        
        <div className="text-sm text-gray-400">
          AI Terminal & IDE
        </div>
      </div>

      {/* Right side - User info and controls */}
      <div className="flex items-center space-x-4">
        {/* Connection Status */}
        <div className="flex items-center text-sm">
          <div className="w-2 h-2 bg-green-400 rounded-full mr-2" />
          <span className="text-gray-300">Connected</span>
        </div>

        {/* User Profile */}
        {userInfo && (
          <div className="relative">
            <button
              onClick={() => setIsMenuOpen(!isMenuOpen)}
              className="flex items-center space-x-2 text-sm bg-gray-700 hover:bg-gray-600 rounded-lg px-3 py-2 transition-colors"
            >
              <div className="w-6 h-6 bg-blue-500 rounded-full flex items-center justify-center">
                <span className="text-xs font-bold text-white">
                  {userInfo.email.charAt(0).toUpperCase()}
                </span>
              </div>
              <div className="text-left">
                <div className="text-white font-medium">{userInfo.email}</div>
                <div className="text-gray-400 text-xs">{userInfo.request_count} requests left</div>
              </div>
              <svg className="w-4 h-4 text-gray-400" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" clipRule="evenodd" />
              </svg>
            </button>

            {/* Dropdown Menu */}
            {isMenuOpen && (
              <div className="absolute right-0 mt-2 w-48 bg-gray-700 rounded-lg shadow-lg border border-gray-600 z-50">
                <div className="py-1">
                  <button
                    onClick={fetchUserInfo}
                    className="block w-full text-left px-4 py-2 text-sm text-gray-300 hover:bg-gray-600"
                  >
                    Refresh Info
                  </button>
                  <hr className="border-gray-600 my-1" />
                  <button
                    onClick={handleLogout}
                    className="block w-full text-left px-4 py-2 text-sm text-red-400 hover:bg-gray-600"
                  >
                    Logout
                  </button>
                </div>
              </div>
            )}
          </div>
        )}

        {/* Settings Button */}
        <button className="p-2 text-gray-400 hover:text-white hover:bg-gray-700 rounded-lg transition-colors">
          <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
            <path fillRule="evenodd" d="M11.49 3.17c-.38-1.56-2.6-1.56-2.98 0a1.532 1.532 0 01-2.286.948c-1.372-.836-2.942.734-2.106 2.106.54.886.061 2.042-.947 2.287-1.561.379-1.561 2.6 0 2.978a1.532 1.532 0 01.947 2.287c-.836 1.372.734 2.942 2.106 2.106a1.532 1.532 0 012.287.947c.379 1.561 2.6 1.561 2.978 0a1.533 1.533 0 012.287-.947c1.372.836 2.942-.734 2.106-2.106a1.533 1.533 0 01.947-2.287c1.561-.379 1.561-2.6 0-2.978a1.532 1.532 0 01-.947-2.287c.836-1.372-.734-2.942-2.106-2.106a1.532 1.532 0 01-2.287-.947zM10 13a3 3 0 100-6 3 3 0 000 6z" clipRule="evenodd" />
          </svg>
        </button>
      </div>
    </header>
  );
}; 