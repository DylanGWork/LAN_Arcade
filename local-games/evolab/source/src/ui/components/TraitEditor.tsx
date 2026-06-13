// Trait Editor UI for modifying cell traits

import React, { useState } from 'react';
import FocusLock from 'react-focus-lock';
import type { Traits } from '../../types/entities';
import { Config } from '../../core/Config';

interface TraitEditorProps {
  currentTraits: Traits;
  availableDNA: number;
  generation: number;
  onApply: (modifications: Partial<Traits>) => void;
}

interface TraitConfig {
  label: string;
  key: keyof Traits;
  min: number;
  max: number;
  step: number;
  maxDelta: number;
}

interface TraitSection {
  title: string;
  traits: TraitConfig[];
}

const traitSections: TraitSection[] = [
  {
    title: '⚡ Energy & Metabolism',
    traits: [
      { label: 'Metabolism Rate', key: 'metabolismRate', min: 0.5, max: 2.0, step: 0.1, maxDelta: 0.5 },
      { label: 'Energy Efficiency', key: 'energyEfficiency', min: 0.5, max: 1.5, step: 0.1, maxDelta: 0.5 },
      { label: 'Photosynthesis', key: 'photosynthesis', min: 0, max: 1.0, step: 0.05, maxDelta: 0.4 },
    ],
  },
  {
    title: '💪 Physical Stats',
    traits: [
      { label: 'Size', key: 'size', min: 1, max: 10, step: 0.5, maxDelta: 2 },
      { label: 'Speed', key: 'speed', min: 1, max: 10, step: 0.5, maxDelta: 2 },
      { label: 'Armor', key: 'armor', min: 0, max: 10, step: 0.5, maxDelta: 2 },
      { label: 'Regeneration', key: 'regeneration', min: 0, max: 5, step: 0.5, maxDelta: 2 },
    ],
  },
  {
    title: '👁️ Senses',
    traits: [
      { label: 'Vision Range', key: 'visionRange', min: 50, max: 500, step: 5, maxDelta: 100 },
      { label: 'Chemotaxis', key: 'chemotaxis', min: 0, max: 10, step: 0.5, maxDelta: 2 },
      { label: 'Hearing', key: 'hearing', min: 0, max: 10, step: 0.5, maxDelta: 2 },
    ],
  },
  {
    title: '🧠 Behavioral',
    traits: [
      { label: 'Aggression', key: 'aggression', min: 0, max: 10, step: 0.5, maxDelta: 2 },
      { label: 'Intelligence', key: 'intelligence', min: 0, max: 10, step: 0.5, maxDelta: 2 },
      { label: 'Fear Response', key: 'fearResponse', min: 0, max: 10, step: 0.5, maxDelta: 2 },
    ],
  },
  {
    title: '✨ Special Abilities',
    traits: [
      { label: 'Toxin Strength', key: 'toxinStrength', min: 0, max: 10, step: 0.5, maxDelta: 2 },
      { label: 'Speed Burst', key: 'speedBurstPower', min: 0, max: 10, step: 0.5, maxDelta: 2 },
      { label: 'Camouflage', key: 'camouflage', min: 0, max: 10, step: 0.5, maxDelta: 2 },
    ],
  },
  {
    title: '🌍 Environmental',
    traits: [
      { label: 'Temperature Tolerance', key: 'temperatureTolerance', min: 0, max: 10, step: 0.5, maxDelta: 2 },
      { label: 'Pressure Resistance', key: 'pressureResistance', min: 0, max: 10, step: 0.5, maxDelta: 2 },
      { label: 'Toxin Resistance', key: 'toxinResistance', min: 0, max: 10, step: 0.5, maxDelta: 2 },
    ],
  },
];

export const TraitEditor: React.FC<TraitEditorProps> = ({
  currentTraits,
  availableDNA,
  generation,
  onApply,
}) => {
  const [modifications, setModifications] = useState<Partial<Traits>>({});
  const [dnaSpent, setDNASpent] = useState(0);
  const [statusMessage, setStatusMessage] = useState('');

  React.useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        e.preventDefault();
        onApply({});
      }
    };

    document.addEventListener('keydown', handleEscape);
    return () => document.removeEventListener('keydown', handleEscape);
  }, [onApply]);

  const decimalsForStep = (step: number | null | undefined): number => {
    const text = String(step ?? 1);
    if (text.includes('e-')) {
      const exponent = Number(text.split('e-')[1] ?? 0);
      return Number.isFinite(exponent) ? exponent : 0;
    }
    const decimal = text.includes('.') ? text.split('.')[1] ?? '' : '';
    return decimal.length;
  };

  const formatValue = (value: number, step: number): string => {
    return value.toFixed(decimalsForStep(step));
  };

  const getAllowedRange = (config: TraitConfig): { min: number; max: number } => {
    const currentValue = currentTraits[config.key] as number;
    return {
      min: Math.max(config.min, currentValue - config.maxDelta),
      max: Math.min(config.max, currentValue + config.maxDelta),
    };
  };

  const normalizeValue = (value: number, config: TraitConfig): number => {
    const range = getAllowedRange(config);
    const clamped = Math.max(range.min, Math.min(range.max, value));
    const stepped = Math.round(clamped / config.step) * config.step;
    const precision = Math.max(0, decimalsForStep(config.step));
    return Number(stepped.toFixed(precision));
  };

  const calculateTotalCost = (mods: Partial<Traits>): number => {
    let cost = 0;
    for (const [key, value] of Object.entries(mods)) {
      if (value !== undefined) {
        const oldValue = currentTraits[key as keyof Traits] as number;
        const diff = Math.abs((value as number) - oldValue);
        cost += diff * Config.DNA_COST_PER_TRAIT_CHANGE;
      }
    }
    return Number(cost.toFixed(2));
  };

  const commitTraitValue = (config: TraitConfig, rawValue: number) => {
    if (!Number.isFinite(rawValue)) {
      setStatusMessage('Enter a number for the trait value.');
      return;
    }

    const currentValue = currentTraits[config.key] as number;
    const newValue = normalizeValue(rawValue, config);
    const nextModifications = { ...modifications };

    if (Math.abs(newValue - currentValue) < config.step / 2) {
      delete (nextModifications as Record<string, number>)[config.key];
    } else {
      (nextModifications as Record<string, number>)[config.key] = newValue;
    }

    const totalCost = calculateTotalCost(nextModifications);
    setModifications(nextModifications);
    setDNASpent(totalCost);

    if (totalCost > availableDNA) {
      setStatusMessage(`Need ${(totalCost - availableDNA).toFixed(1)} more DNA points for these changes.`);
    } else {
      setStatusMessage('');
    }
  };

  const handleApply = () => {
    if (dnaSpent > availableDNA) {
      setStatusMessage(`Need ${(dnaSpent - availableDNA).toFixed(1)} more DNA points before applying.`);
      return;
    }
    onApply(modifications);
  };

  const handleCancel = () => {
    onApply({});
  };

  const handleReset = () => {
    setModifications({});
    setDNASpent(0);
    setStatusMessage('');
  };

  const renderTraitControl = (config: TraitConfig) => {
    const currentValue = currentTraits[config.key] as number;
    const modifiedValue = (modifications[config.key] as number) ?? currentValue;
    const hasChanged = Math.abs(modifiedValue - currentValue) >= config.step / 2;
    const allowedRange = getAllowedRange(config);
    const diff = modifiedValue - currentValue;
    const traitCost = Math.abs(diff) * Config.DNA_COST_PER_TRAIT_CHANGE;

    return (
      <div className="trait-row" key={config.key}>
        <label className="trait-label" htmlFor={`trait-${config.key}`}>
          {config.label}
          {hasChanged && <span className="changed-indicator">*</span>}
        </label>

        <input
          id={`trait-${config.key}`}
          type="range"
          min={allowedRange.min}
          max={allowedRange.max}
          step={config.step}
          value={modifiedValue}
          onChange={e => commitTraitValue(config, parseFloat(e.target.value))}
          className="trait-slider"
        />

        <button
          type="button"
          className="stepper-button"
          onClick={() => commitTraitValue(config, modifiedValue - config.step)}
          aria-label={`Decrease ${config.label}`}
        >
          -
        </button>

        <input
          type="number"
          min={allowedRange.min}
          max={allowedRange.max}
          step={config.step}
          value={formatValue(modifiedValue, config.step)}
          onChange={e => commitTraitValue(config, parseFloat(e.target.value))}
          className="trait-number"
          aria-label={`${config.label} value`}
        />

        <button
          type="button"
          className="stepper-button"
          onClick={() => commitTraitValue(config, modifiedValue + config.step)}
          aria-label={`Increase ${config.label}`}
        >
          +
        </button>

        <span className="trait-value">
          {hasChanged ? (
            <>
              <span className="trait-diff">
                {diff > 0 ? '+' : ''}
                {formatValue(diff, config.step)}
              </span>
              <span className="trait-cost">DNA {traitCost.toFixed(1)}</span>
            </>
          ) : (
            <span className="trait-diff neutral">Current</span>
          )}
        </span>
      </div>
    );
  };

  return (
    <div
      className="trait-editor-overlay"
      role="dialog"
      aria-modal="true"
      aria-labelledby="trait-editor-title"
      aria-describedby="trait-editor-description"
    >
      <FocusLock returnFocus>
        <div className="trait-editor">
          <div className="editor-header">
            <h2 id="trait-editor-title">🧬 Trait Editor - Generation {generation}</h2>
            <div id="trait-editor-description" className={dnaSpent > availableDNA ? 'dna-display over-budget' : 'dna-display'}>
              DNA Points: {(availableDNA - dnaSpent).toFixed(1)} / {availableDNA.toFixed(1)}
              {dnaSpent > 0 && <span className="dna-spent"> (-{dnaSpent.toFixed(1)})</span>}
            </div>
            {statusMessage && <div className="status-message">{statusMessage}</div>}
          </div>

          <div className="editor-content">
            {traitSections.map(section => (
              <div className="trait-section" key={section.title}>
                <h3>{section.title}</h3>
                {section.traits.map(renderTraitControl)}
              </div>
            ))}
          </div>

          <div className="editor-footer">
            <div className="button-group">
              <button onClick={handleReset} className="btn btn-secondary">
                Reset Changes
              </button>
              <button onClick={handleCancel} className="btn btn-secondary">
                Skip (No Changes)
              </button>
              <button onClick={handleApply} className="btn btn-primary" disabled={dnaSpent > availableDNA}>
                {Object.keys(modifications).length === 0 ? 'Continue (No Changes)' : 'Apply Modifications'}
              </button>
            </div>
            <div className="info-text">
              Use sliders, +/- buttons, or type a value. Vision can shift by up to 100 per generation; most traits shift by up to 2.
            </div>
          </div>

          <style>{`
        .trait-editor-overlay {
          position: fixed;
          top: 0;
          left: 0;
          width: 100vw;
          height: 100vh;
          background: rgba(0, 0, 0, 0.9);
          display: flex;
          justify-content: center;
          align-items: center;
          z-index: 1000;
        }

        .trait-editor {
          background: #1a1e2e;
          border-radius: 12px;
          width: 92%;
          max-width: 980px;
          max-height: 90vh;
          overflow: hidden;
          display: flex;
          flex-direction: column;
          box-shadow: 0 10px 40px rgba(0, 0, 0, 0.5);
        }

        .editor-header {
          padding: 20px;
          background: linear-gradient(135deg, #2d3548 0%, #1a1e2e 100%);
          border-bottom: 2px solid #4caf50;
        }

        .editor-header h2 {
          margin: 0 0 10px 0;
          color: #4caf50;
          font-size: 24px;
        }

        .dna-display {
          font-size: 18px;
          color: #fff;
          font-family: 'Courier New', monospace;
        }

        .dna-display.over-budget {
          color: #ff8a80;
        }

        .dna-spent {
          color: #ff9800;
        }

        .status-message {
          margin-top: 8px;
          color: #ffcc80;
          font-size: 13px;
        }

        .editor-content {
          flex: 1;
          overflow-y: auto;
          padding: 20px;
        }

        .trait-section {
          margin-bottom: 30px;
        }

        .trait-section h3 {
          color: #4caf50;
          margin-bottom: 15px;
          font-size: 18px;
        }

        .trait-row {
          display: grid;
          grid-template-columns: 170px minmax(160px, 1fr) 36px 96px 36px 130px;
          gap: 10px;
          align-items: center;
          margin-bottom: 12px;
        }

        .trait-label {
          color: #ddd;
          font-size: 14px;
        }

        .changed-indicator {
          color: #ff9800;
          margin-left: 5px;
        }

        .trait-slider {
          width: 100%;
          min-width: 0;
        }

        .stepper-button {
          width: 36px;
          height: 34px;
          border: 1px solid #4caf50;
          border-radius: 6px;
          background: #283142;
          color: #fff;
          cursor: pointer;
          font-size: 18px;
          font-weight: bold;
        }

        .stepper-button:hover {
          background: #354158;
        }

        .trait-number {
          width: 96px;
          height: 34px;
          border: 1px solid #4caf50;
          border-radius: 6px;
          background: #0f1219;
          color: #fff;
          padding: 0 8px;
          font-family: 'Courier New', monospace;
          font-size: 14px;
        }

        .trait-value {
          display: flex;
          flex-direction: column;
          align-items: flex-end;
          gap: 2px;
          color: #fff;
          font-family: 'Courier New', monospace;
          font-size: 13px;
        }

        .trait-diff {
          color: #4caf50;
        }

        .trait-diff.neutral {
          color: #888;
        }

        .trait-cost {
          color: #ffcc80;
          font-size: 11px;
        }

        .editor-footer {
          padding: 20px;
          background: #0f1219;
          border-top: 1px solid #333;
        }

        .button-group {
          display: flex;
          gap: 10px;
          margin-bottom: 10px;
        }

        .btn {
          padding: 12px 24px;
          border: none;
          border-radius: 6px;
          font-size: 14px;
          cursor: pointer;
          transition: all 0.2s;
          font-family: inherit;
        }

        .btn-primary {
          background: #4caf50;
          color: white;
        }

        .btn-primary:hover:not(:disabled) {
          background: #45a049;
        }

        .btn-primary:disabled {
          background: #555;
          cursor: not-allowed;
          opacity: 0.5;
        }

        .btn-secondary {
          background: #555;
          color: white;
        }

        .btn-secondary:hover {
          background: #666;
        }

        .info-text {
          color: #aaa;
          font-size: 12px;
          text-align: center;
        }

        @media (max-width: 760px) {
          .trait-editor {
            width: 96%;
          }

          .editor-header,
          .editor-footer,
          .editor-content {
            padding: 14px;
          }

          .trait-row {
            grid-template-columns: 1fr 34px 88px 34px;
            gap: 8px;
          }

          .trait-label,
          .trait-slider,
          .trait-value {
            grid-column: 1 / -1;
          }

          .trait-value {
            align-items: flex-start;
          }

          .button-group {
            flex-wrap: wrap;
          }

          .btn {
            flex: 1 1 150px;
          }
        }
      `}</style>
        </div>
      </FocusLock>
    </div>
  );
};
