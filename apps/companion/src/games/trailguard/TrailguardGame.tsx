import { useEffect, useMemo, useRef, useState } from 'react';
import type { Challenge, Player, ScoreSubmission } from '@lan-arcade/shared';
import { calculateTrailguardScore, createTrailguardMap, type Point, waveSpec } from './engine';

interface Props {
  challenge: Challenge | null;
  player: Player | null;
  sessionToken: string;
  onSubmitScore: (score: ScoreSubmission) => Promise<void>;
}

interface GameSummary {
  score: number;
  wave: number;
  kills: number;
  lives: number;
  leaks: number;
  money: number;
  durationMs: number;
}

interface RuntimeEnemy {
  circle: Phaser.GameObjects.Arc;
  hp: number;
  maxHp: number;
  speed: number;
  targetIndex: number;
  alive: boolean;
}

interface RuntimeTower {
  spot: Point;
  level: number;
  range: number;
  cooldown: number;
  body: Phaser.GameObjects.Arc;
}

const width = 720;
const height = 480;

export function TrailguardGame({ challenge, player, sessionToken, onSubmitScore }: Props) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const [summary, setSummary] = useState<GameSummary | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const seed = challenge?.seed || 'local-practice';
  const map = useMemo(() => createTrailguardMap(seed), [seed]);
  const smokeMode = window.localStorage.getItem('lanArcade.smokeMode') === '1';
  const maxWaves = smokeMode ? 1 : 5;

  useEffect(() => {
    let destroyed = false;
    let game: Phaser.Game | null = null;

    async function boot() {
      const Phaser = await import('phaser');
      if (!containerRef.current || destroyed) return;

      class TrailguardScene extends Phaser.Scene {
        money = 115;
        lives = 12;
        wave = 0;
        kills = 0;
        leaks = 0;
        startedAt = performance.now();
        enemies: RuntimeEnemy[] = [];
        towers: RuntimeTower[] = [];
        infoText!: Phaser.GameObjects.Text;
        statusText!: Phaser.GameObjects.Text;
        nextWaveText!: Phaser.GameObjects.Text;
        spawnTimer = 0;
        spawnedThisWave = 0;
        currentWave = waveSpec(1);
        waveActive = false;

        create() {
          this.cameras.main.setBackgroundColor('#101820');
          this.drawMap();
          this.infoText = this.add.text(16, 14, '', { color: '#f6f7eb', fontFamily: 'Arial', fontSize: '18px' });
          this.statusText = this.add.text(16, 438, 'Tap a build pad to place or upgrade a tower.', {
            color: '#c7d2fe',
            fontFamily: 'Arial',
            fontSize: '16px'
          });
          this.nextWaveText = this.add.text(520, 18, 'Start Wave', {
            color: '#101820',
            backgroundColor: '#7dd87d',
            padding: { x: 14, y: 9 },
            fontFamily: 'Arial',
            fontSize: '18px'
          }).setInteractive({ useHandCursor: true });
          this.nextWaveText.on('pointerdown', () => this.startWave());
          this.updateInfo();
        }

        drawMap() {
          const graphics = this.add.graphics();
          graphics.lineStyle(34, 0x6d5f47, 1);
          graphics.beginPath();
          graphics.moveTo(map.path[0].x, map.path[0].y);
          for (const point of map.path.slice(1)) graphics.lineTo(point.x, point.y);
          graphics.strokePath();
          graphics.lineStyle(22, 0xb8a36a, 1);
          graphics.beginPath();
          graphics.moveTo(map.path[0].x, map.path[0].y);
          for (const point of map.path.slice(1)) graphics.lineTo(point.x, point.y);
          graphics.strokePath();

          map.towerSpots.forEach((spot) => {
            const pad = this.add.circle(spot.x, spot.y, 22, 0x1e3a5f).setStrokeStyle(3, 0x67e8f9);
            pad.setInteractive({ useHandCursor: true });
            pad.on('pointerdown', () => this.buildOrUpgradeTower(spot));
          });
        }

        buildOrUpgradeTower(spot: Point) {
          const existing = this.towers.find((tower) => distance(tower.spot, spot) < 3);
          if (existing) {
            const cost = 55 + existing.level * 35;
            if (this.money < cost || existing.level >= 3) return;
            this.money -= cost;
            existing.level += 1;
            existing.range += 18;
            existing.body.setFillStyle(existing.level === 2 ? 0xfacc15 : 0xf97316);
            existing.body.setScale(1 + existing.level * 0.12);
            this.statusText.setText(`Tower upgraded to level ${existing.level}.`);
            this.updateInfo();
            return;
          }

          if (this.money < 45) return;
          this.money -= 45;
          const body = this.add.circle(spot.x, spot.y, 16, 0x38bdf8).setStrokeStyle(3, 0xe0f2fe);
          this.towers.push({ spot, level: 1, range: 105, cooldown: 0, body });
          this.statusText.setText('Tower built. Tap it again to upgrade.');
          this.updateInfo();
        }

        startWave() {
          if (this.waveActive) return;
          this.wave += 1;
          this.currentWave = waveSpec(this.wave);
          if (smokeMode) {
            this.currentWave.enemyCount = 2;
            this.currentWave.enemyHealth = 18;
            this.currentWave.enemySpeed = 80;
          }
          this.spawnedThisWave = 0;
          this.spawnTimer = 0;
          this.waveActive = true;
          this.nextWaveText.setText('Wave Running');
          this.statusText.setText(`Wave ${this.wave}: hold the trail.`);
          this.updateInfo();
        }

        update(_time: number, delta: number) {
          const dt = delta / 1000;
          if (this.waveActive) this.spawnEnemies(dt);
          this.moveEnemies(dt);
          this.fireTowers(dt);
          if (this.waveActive && this.spawnedThisWave >= this.currentWave.enemyCount && this.enemies.every((enemy) => !enemy.alive)) {
            this.waveActive = false;
            this.money += 35 + this.wave * 8;
            if (this.wave >= maxWaves) this.finishGame();
            else this.nextWaveText.setText('Start Wave');
            this.updateInfo();
          }
        }

        spawnEnemies(dt: number) {
          this.spawnTimer -= dt;
          if (this.spawnTimer > 0 || this.spawnedThisWave >= this.currentWave.enemyCount) return;
          this.spawnTimer = 0.65;
          this.spawnedThisWave += 1;
          const circle = this.add.circle(map.path[0].x, map.path[0].y, 11, 0xef4444).setStrokeStyle(2, 0xfee2e2);
          this.enemies.push({
            circle,
            hp: this.currentWave.enemyHealth,
            maxHp: this.currentWave.enemyHealth,
            speed: this.currentWave.enemySpeed,
            targetIndex: 1,
            alive: true
          });
        }

        moveEnemies(dt: number) {
          for (const enemy of this.enemies) {
            if (!enemy.alive) continue;
            const target = map.path[enemy.targetIndex];
            const current = { x: enemy.circle.x, y: enemy.circle.y };
            const gap = distance(current, target);
            if (gap < 4) {
              enemy.targetIndex += 1;
              if (enemy.targetIndex >= map.path.length) {
                enemy.alive = false;
                enemy.circle.destroy();
                this.lives -= 1;
                this.leaks += 1;
                if (this.lives <= 0) this.finishGame();
                this.updateInfo();
              }
              continue;
            }
            const step = Math.min(gap, enemy.speed * dt);
            enemy.circle.x += ((target.x - current.x) / gap) * step;
            enemy.circle.y += ((target.y - current.y) / gap) * step;
          }
        }

        fireTowers(dt: number) {
          for (const tower of this.towers) {
            tower.cooldown -= dt;
            if (tower.cooldown > 0) continue;
            const target = this.enemies.find((enemy) => enemy.alive && distance(tower.spot, { x: enemy.circle.x, y: enemy.circle.y }) <= tower.range);
            if (!target) continue;
            tower.cooldown = Math.max(0.22, 0.82 - tower.level * 0.14);
            target.hp -= 22 + tower.level * 16;
            this.add.line(0, 0, tower.spot.x, tower.spot.y, target.circle.x, target.circle.y, 0x93c5fd, 0.75)
              .setOrigin(0, 0)
              .setBlendMode(Phaser.BlendModes.ADD);
            this.time.delayedCall(70, () => this.children.list
              .filter((child) => child instanceof Phaser.GameObjects.Line)
              .slice(0, 1)
              .forEach((child) => child.destroy()));
            target.circle.setScale(Math.max(0.55, target.hp / target.maxHp));
            if (target.hp <= 0) {
              target.alive = false;
              target.circle.destroy();
              this.kills += 1;
              this.money += this.currentWave.bounty;
              this.updateInfo();
            }
          }
        }

        finishGame() {
          this.waveActive = false;
          const durationMs = Math.floor(performance.now() - this.startedAt);
          const score = calculateTrailguardScore({
            kills: this.kills,
            wave: this.wave,
            lives: Math.max(0, this.lives),
            leaks: this.leaks,
            money: this.money,
            durationMs
          });
          this.scene.pause();
          setSummary({
            score,
            wave: this.wave,
            kills: this.kills,
            lives: Math.max(0, this.lives),
            leaks: this.leaks,
            money: this.money,
            durationMs
          });
        }

        updateInfo() {
          this.infoText.setText(`Wave ${this.wave}/${maxWaves}   Lives ${this.lives}   Money ${this.money}   Kills ${this.kills}`);
        }
      }

      game = new Phaser.Game({
        type: Phaser.AUTO,
        parent: containerRef.current,
        width,
        height,
        backgroundColor: '#101820',
        scale: {
          mode: Phaser.Scale.FIT,
          autoCenter: Phaser.Scale.CENTER_BOTH
        },
        scene: TrailguardScene
      });
    }

    boot();
    return () => {
      destroyed = true;
      if (game) game.destroy(true);
    };
  }, [map, maxWaves, seed, smokeMode]);

  async function submitScore() {
    if (!summary || !player || !challenge || !sessionToken) return;
    setSubmitting(true);
    try {
      await onSubmitScore({
        gameId: 'trailguard-td',
        playerId: player.id,
        score: summary.score,
        mode: 'challenge',
        difficulty: challenge.difficulty,
        seed: challenge.seed,
        durationMs: summary.durationMs,
        details: {
          wave: summary.wave,
          kills: summary.kills,
          lives: summary.lives,
          leaks: summary.leaks,
          money: summary.money
        }
      });
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <section className="game-surface" data-testid="trailguard-game">
      <div className="game-head">
        <div>
          <h2>Trailguard TD</h2>
          <p>Seed {seed}. Build towers on blue pads, survive {maxWaves} wave{maxWaves === 1 ? '' : 's'}, then submit the score.</p>
        </div>
        {summary && <strong>{summary.score.toLocaleString()} pts</strong>}
      </div>
      <div className="phaser-wrap" ref={containerRef} />
      {summary && (
        <div className="score-panel">
          <span>Wave {summary.wave}</span>
          <span>Kills {summary.kills}</span>
          <span>Lives {summary.lives}</span>
          <button type="button" onClick={submitScore} disabled={!player || !sessionToken || submitting}>
            {submitting ? 'Submitting...' : 'Submit Score'}
          </button>
        </div>
      )}
    </section>
  );
}

function distance(a: Point, b: Point): number {
  return Math.hypot(a.x - b.x, a.y - b.y);
}
