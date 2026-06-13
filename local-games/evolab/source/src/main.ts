// Main entry point for EvoLab

import { GameLoop } from './core/GameLoop';

function isKnownPixiShaderLogError(message: unknown, error?: unknown): boolean {
  const text = String(message ?? '');
  const stack = error instanceof Error ? error.stack ?? '' : '';
  return text.includes("Cannot read properties of null (reading 'split')") &&
    stack.includes('vendor-graphics');
}

const previousOnError = window.onerror;
window.onerror = (message, source, lineno, colno, error) => {
  if (isKnownPixiShaderLogError(message, error)) {
    return true;
  }

  if (typeof previousOnError === 'function') {
    return previousOnError(message, source, lineno, colno, error);
  }

  return false;
};

window.addEventListener('unhandledrejection', event => {
  if (isKnownPixiShaderLogError(event.reason instanceof Error ? event.reason.message : event.reason, event.reason)) {
    event.preventDefault();
  }
});

// Initialize and start the game
async function main() {
  // console.log('🧬 Welcome to EvoLab - Evolution Simulator');

  const game = new GameLoop();

  try {
    await game.initialize();
    game.start();
  } catch (error) {
    console.error('Failed to initialize game:', error);
  }

  // Cleanup on window unload
  window.addEventListener('beforeunload', () => {
    game.dispose();
  });
}

// Start the game when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', main);
} else {
  main();
}
