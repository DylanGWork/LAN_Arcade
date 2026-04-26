import { useMemo, useState } from 'react';
import type { Challenge, Player, ScoreSubmission } from '@lan-arcade/shared';
import { seededRandom } from '../trailguard/engine';

interface Props {
  challenge: Challenge | null;
  player: Player | null;
  onSubmitScore: (score: ScoreSubmission) => Promise<void>;
}

export function NumberSplashGame({ challenge, player, onSubmitScore }: Props) {
  const [round, setRound] = useState(1);
  const [score, setScore] = useState(0);
  const [misses, setMisses] = useState(0);
  const [startedAt] = useState(() => performance.now());
  const seed = challenge?.seed || 'number-practice';
  const options = useMemo(() => makeRound(seed, round), [round, seed]);
  const done = round > 8;

  async function choose(value: number) {
    if (done) return;
    if (value === options.target) {
      setScore((current) => current + 100 + round * 12);
    } else {
      setMisses((current) => current + 1);
    }
    setRound((current) => current + 1);
  }

  async function submit() {
    if (!player || !challenge) return;
    await onSubmitScore({
      gameId: 'number-splash',
      playerId: player.id,
      score: Math.max(0, score - misses * 25),
      mode: 'challenge',
      difficulty: challenge.difficulty,
      seed: challenge.seed,
      durationMs: Math.floor(performance.now() - startedAt),
      details: { round: round - 1, misses }
    });
  }

  return (
    <section className="game-surface" data-testid="number-splash-game">
      <div className="game-head">
        <div>
          <h2>Number Splash</h2>
          <p>Tap the bubble showing {done ? 'your final score' : `number ${options.target}`}.</p>
        </div>
        <strong>{Math.max(0, score - misses * 25)} pts</strong>
      </div>
      {!done ? (
        <div className="bubble-grid">
          {options.values.map((value) => (
            <button className="bubble" type="button" key={value} onClick={() => choose(value)}>
              {value}
            </button>
          ))}
        </div>
      ) : (
        <div className="score-panel">
          <span>Rounds 8</span>
          <span>Misses {misses}</span>
          <button type="button" disabled={!player} onClick={submit}>Submit Score</button>
        </div>
      )}
    </section>
  );
}

function makeRound(seed: string, round: number) {
  const random = seededRandom(`${seed}:${round}`);
  const target = 1 + Math.floor(random() * 10);
  const values = new Set<number>([target]);
  while (values.size < 4) values.add(1 + Math.floor(random() * 10));
  return {
    target,
    values: [...values].sort(() => random() - 0.5)
  };
}
