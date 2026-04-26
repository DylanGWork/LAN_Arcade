import { useEffect, useMemo, useState } from 'react';
import type { Challenge, Player, ScoreSubmission } from '@lan-arcade/shared';
import {
  applyCampAction,
  campActions,
  canUseCampAction,
  createCampColony,
  createCampMap,
  type CampActionId
} from './engine';

interface Props {
  challenge: Challenge | null;
  player: Player | null;
  onSubmitScore: (score: ScoreSubmission) => Promise<void>;
}

export function CampColonyGame({ challenge, player, onSubmitScore }: Props) {
  const seed = challenge?.seed || 'camp-colony-practice';
  const maxTurns = window.localStorage.getItem('lanArcade.smokeMode') === '1' ? 4 : 10;
  const map = useMemo(() => createCampMap(seed), [seed]);
  const [state, setState] = useState(() => createCampColony(seed, { maxTurns }));
  const [startedAt, setStartedAt] = useState(() => performance.now());
  const [submitted, setSubmitted] = useState(false);

  useEffect(() => {
    setState(createCampColony(seed, { maxTurns }));
    setStartedAt(performance.now());
    setSubmitted(false);
  }, [maxTurns, seed]);

  function act(actionId: CampActionId) {
    setState((current) => applyCampAction(current, actionId));
  }

  async function submit() {
    if (!player || submitted) return;
    await onSubmitScore({
      gameId: 'camp-colony',
      playerId: player.id,
      score: state.score,
      mode: challenge ? 'challenge' : 'practice',
      difficulty: challenge?.difficulty || 'normal',
      seed,
      durationMs: Math.floor(performance.now() - startedAt),
      details: {
        turn: Math.min(state.turn - 1, state.maxTurns),
        population: state.population,
        morale: state.morale,
        threat: state.threat,
        buildings: state.buildings,
        failed: state.failed
      }
    });
    setSubmitted(true);
  }

  return (
    <section className="game-surface colony-game" data-testid="camp-colony-game">
      <div className="game-head">
        <div>
          <h2>Camp Colony</h2>
          <p>Turn {Math.min(state.turn, state.maxTurns)} of {state.maxTurns} - survive, build, and keep the camp calm.</p>
        </div>
        <strong>{state.score.toLocaleString()} pts</strong>
      </div>

      <div className="colony-layout">
        <div className="colony-map" style={{ gridTemplateColumns: `repeat(${map.width}, 1fr)` }} aria-label="Camp map">
          {map.tiles.map((tile, index) => {
            const revealed = index < state.explored + 3;
            const center = tile.x === Math.floor(map.width / 2) && tile.y === Math.floor(map.height / 2);
            return (
              <div
                className={`camp-tile terrain-${tile.terrain} ${revealed ? 'revealed' : ''} ${center ? 'base' : ''}`}
                key={tile.id}
              >
                <span>{center ? 'Base' : revealed ? tile.terrain : '?'}</span>
                {revealed && !center && <small>{tile.value}</small>}
              </div>
            );
          })}
        </div>

        <div className="colony-side">
          <div className="resource-grid">
            <Meter label="Food" value={state.food} />
            <Meter label="Parts" value={state.parts} />
            <Meter label="Power" value={state.power} />
            <Meter label="People" value={state.population} />
            <Meter label="Morale" value={state.morale} />
            <Meter label="Threat" value={state.threat} danger />
          </div>

          <div className="buildings-row" aria-label="Camp buildings">
            <span>Gardens {state.buildings.gardens}</span>
            <span>Solar {state.buildings.solar}</span>
            <span>Towers {state.buildings.watchtowers}</span>
            <span>Shops {state.buildings.workshops}</span>
            <span>Scouts {state.scouts}</span>
            <span>Tech {state.tech}</span>
          </div>
        </div>
      </div>

      {!state.complete ? (
        <div className="action-grid">
          {campActions.map((action) => (
            <button
              type="button"
              className="action-card"
              key={action.id}
              disabled={!canUseCampAction(state, action.id)}
              onClick={() => act(action.id)}
            >
              <strong>{action.label}</strong>
              <span>{action.description}</span>
            </button>
          ))}
        </div>
      ) : (
        <div className="score-panel">
          <span>{state.failed ? 'Colony failed' : 'Challenge survived'}</span>
          <span>Final score {state.score.toLocaleString()}</span>
          <button type="button" disabled={!player || submitted} onClick={submit}>
            {submitted ? 'Score Submitted' : 'Submit Camp Colony Score'}
          </button>
        </div>
      )}

      <div className="event-log" aria-label="Camp log">
        {state.log.map((entry, index) => (
          <p key={`${entry}:${index}`}>{entry}</p>
        ))}
      </div>
    </section>
  );
}

function Meter({ label, value, danger = false }: { label: string; value: number; danger?: boolean }) {
  return (
    <div className={`meter ${danger ? 'meter-danger' : ''}`}>
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}
