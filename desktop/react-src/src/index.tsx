import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import App from './App';

const root = ReactDOM.createRoot(
  document.getElementById('root') as HTMLElement
);

root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);

//! инициализируем Neutralino только если мы в Neutralino среде
const initializeNeutralinoIfNeeded = async () => {
  try {
    if (typeof window !== 'undefined' && 'Neutralino' in window) {
      const { init } = await import('@neutralinojs/lib');
      init();
    }
  } catch (error) {
    console.warn('Neutralino initialization failed (running in browser mode):', error);
  }
};

initializeNeutralinoIfNeeded(); 