import React from 'react';
import { Outlet, NavLink } from 'react-router-dom';

const Layout = () => {
  return (
    <div className="min-h-screen flex flex-col">
      {/* Header */}
      <header className="bg-primary-700 text-white shadow-md">
        <div className="container mx-auto px-4 py-3 flex items-center justify-between">
          <NavLink to="/" className="flex items-center gap-2">
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className="w-8 h-8">
              <path d="M11.7 2.805a.75.75 0 01.6 0A60.65 60.65 0 0122.83 8.72a.75.75 0 01-.231 1.337 49.949 49.949 0 00-9.902 3.912l-.003.002-.34.18a.75.75 0 01-.707 0A50.009 50.009 0 007.5 12.174v-.224c0-.131.067-.248.172-.311a54.614 54.614 0 014.653-2.52.75.75 0 00-.65-1.352 56.129 56.129 0 00-4.78 2.589 1.858 1.858 0 00-.859 1.228 49.803 49.803 0 00-4.634-1.527.75.75 0 01-.231-1.337A60.653 60.653 0 0111.7 2.805z" />
              <path d="M13.06 15.473a48.45 48.45 0 017.666-3.282c.134 1.414.22 2.843.255 4.285a.75.75 0 01-.46.71 47.878 47.878 0 00-8.105 4.342.75.75 0 01-.832 0 47.877 47.877 0 00-8.104-4.342.75.75 0 01-.461-.71c.035-1.442.121-2.87.255-4.286A48.4 48.4 0 016 13.18v1.27a1.5 1.5 0 00-.14 2.508c-.09.38-.222.753-.397 1.11.452.213.901.434 1.346.661a6.729 6.729 0 00.551-1.608 1.5 1.5 0 00.14-2.67v-.645a48.549 48.549 0 013.44 1.668 2.25 2.25 0 002.12 0z" />
              <path d="M4.462 19.462c.42-.419.753-.89 1-1.394.453.213.902.434 1.347.661a6.743 6.743 0 01-1.286 1.794.75.75 0 11-1.06-1.06z" />
            </svg>
            <span className="text-xl font-bold">TechnicIA</span>
          </NavLink>
          
          <nav className="hidden md:flex gap-6">
            <NavLink 
              to="/" 
              className={({ isActive }) => 
                `transition-colors ${isActive ? 'text-white font-bold' : 'text-primary-100 hover:text-white'}`
              }
              end
            >
              Accueil
            </NavLink>
            <NavLink 
              to="/upload" 
              className={({ isActive }) => 
                `transition-colors ${isActive ? 'text-white font-bold' : 'text-primary-100 hover:text-white'}`
              }
            >
              Documentation
            </NavLink>
            <NavLink 
              to="/chat" 
              className={({ isActive }) => 
                `transition-colors ${isActive ? 'text-white font-bold' : 'text-primary-100 hover:text-white'}`
              }
            >
              Chat
            </NavLink>
            <NavLink 
              to="/diagnostic" 
              className={({ isActive }) => 
                `transition-colors ${isActive ? 'text-white font-bold' : 'text-primary-100 hover:text-white'}`
              }
            >
              Diagnostic
            </NavLink>
          </nav>
          
          {/* Mobile menu button */}
          <button className="md:hidden p-2 rounded-md text-primary-100 hover:text-white focus:outline-none">
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" className="w-6 h-6">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
            </svg>
          </button>
        </div>
      </header>
      
      {/* Mobile menu (hidden by default) */}
      <div className="hidden bg-primary-600 md:hidden">
        <div className="px-2 pt-2 pb-3 space-y-1">
          <NavLink 
            to="/" 
            className={({ isActive }) => 
              `block px-3 py-2 rounded-md text-base font-medium ${isActive ? 'bg-primary-700 text-white' : 'text-primary-100 hover:bg-primary-500 hover:text-white'}`
            }
            end
          >
            Accueil
          </NavLink>
          <NavLink 
            to="/upload" 
            className={({ isActive }) => 
              `block px-3 py-2 rounded-md text-base font-medium ${isActive ? 'bg-primary-700 text-white' : 'text-primary-100 hover:bg-primary-500 hover:text-white'}`
            }
          >
            Documentation
          </NavLink>
          <NavLink 
            to="/chat" 
            className={({ isActive }) => 
              `block px-3 py-2 rounded-md text-base font-medium ${isActive ? 'bg-primary-700 text-white' : 'text-primary-100 hover:bg-primary-500 hover:text-white'}`
            }
          >
            Chat
          </NavLink>
          <NavLink 
            to="/diagnostic" 
            className={({ isActive }) => 
              `block px-3 py-2 rounded-md text-base font-medium ${isActive ? 'bg-primary-700 text-white' : 'text-primary-100 hover:bg-primary-500 hover:text-white'}`
            }
          >
            Diagnostic
          </NavLink>
        </div>
      </div>
      
      {/* Main content */}
      <main className="flex-grow container mx-auto px-4 py-6">
        <Outlet />
      </main>
      
      {/* Footer */}
      <footer className="bg-gray-100 border-t border-gray-200">
        <div className="container mx-auto px-4 py-4 text-center text-gray-600 text-sm">
          <p>&copy; {new Date().getFullYear()} TechnicIA - Assistant intelligent de maintenance technique</p>
        </div>
      </footer>
    </div>
  );
};

export default Layout;
