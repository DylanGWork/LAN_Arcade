// Cell entity representing a single-celled organism

import { Graphics } from 'pixi.js';
import type { Vector2D, Traits, CompoundStorage } from '../types/entities';
import { Config } from '../core/Config';
import { Genome } from '../genetics/Genome';

export class Cell {
  public id: string;
  public position: Vector2D;
  public velocity: Vector2D;
  public traits: Traits;
  public sprite: Graphics;
  public isPlayer: boolean;
  public genome: Genome;
  public compounds: CompoundStorage;
  public survivalTime = 0;
  public birthTime: number;
  public lastReproductionTime = 0;
  private deathCallback: ((cause: 'atp' | 'health') => void) | null = null;

  constructor(
    id: string,
    x: number,
    y: number,
    genome: Genome,
    sprite: Graphics,
    isPlayer = false
  ) {
    this.id = id;
    this.position = { x, y };
    this.velocity = { x: 0, y: 0 };
    this.genome = genome;
    this.traits = genome.traits;
    this.sprite = sprite;
    this.isPlayer = isPlayer;
    this.birthTime = Date.now();
    this.compounds = {
      glucose: 0,
      aminoAcids: 0,
      phosphates: 0,
    };
  }

  // Update cell state each frame
  update(deltaTime: number): void {
    const simulationSteps = this.getSimulationSteps(deltaTime);

    // Update position based on velocity
    this.position.x += this.velocity.x * simulationSteps;
    this.position.y += this.velocity.y * simulationSteps;

    // Apply friction
    const frictionFactor = Math.pow(Config.FRICTION, simulationSteps);
    this.velocity.x *= frictionFactor;
    this.velocity.y *= frictionFactor;

    // Update sprite position
    this.sprite.x = this.position.x;
    this.sprite.y = this.position.y;

    // Drain ATP over time and heal passive damage
    this.drainATP(simulationSteps);
    this.regenerateHealth(deltaTime);

    // Update survival time
    this.survivalTime = (Date.now() - this.birthTime) / 1000;

    // Boundary check (keep within lake)
    this.constrainToLake();
  }

  // Collect compound
  collectCompound(type: 'glucose' | 'aminoAcid' | 'phosphate', amount: number): void {
    if (type === 'glucose') {
      this.compounds.glucose += amount;
    } else if (type === 'aminoAcid') {
      this.compounds.aminoAcids += amount;
    } else if (type === 'phosphate') {
      this.compounds.phosphates += amount;
    }

    // Clamp to max storage
    const maxStorage = this.traits.maxStorage;
    this.compounds.glucose = Math.min(this.compounds.glucose, maxStorage);
    this.compounds.aminoAcids = Math.min(this.compounds.aminoAcids, maxStorage);
    this.compounds.phosphates = Math.min(this.compounds.phosphates, maxStorage);
  }

  // Check if reproduction requirements are met
  canReproduce(): boolean {
    const atpPercent = (this.traits.atp / this.traits.maxATP) * 100;
    const timeSinceLastReproduction = (Date.now() - this.lastReproductionTime) / 1000;

    return (
      atpPercent >= Config.REPRODUCTION_ATP_THRESHOLD &&
      this.compounds.glucose >= Config.REPRODUCTION_GLUCOSE_REQUIRED &&
      this.compounds.aminoAcids >= Config.REPRODUCTION_AMINO_ACIDS_REQUIRED &&
      this.compounds.phosphates >= Config.REPRODUCTION_PHOSPHATES_REQUIRED &&
      timeSinceLastReproduction >= Config.REPRODUCTION_COOLDOWN_SECONDS
    );
  }

  // Update last reproduction time
  markReproduction(): void {
    this.lastReproductionTime = Date.now();
  }

  // Apply movement force (for player input)
  applyForce(direction: Vector2D, speed: number): void {
    const armorDrag = 1 - Math.min(0.45, Math.max(0, this.traits.armor || 0) * 0.04);
    const sizeDrag = 1 - Math.min(0.25, Math.max(0, (this.traits.size || 5) - 5) * 0.035);
    const effectiveSpeed = speed * armorDrag * sizeDrag;

    this.velocity.x += direction.x * effectiveSpeed;
    this.velocity.y += direction.y * effectiveSpeed;

    // Cap maximum velocity with trait trade-offs: speed helps, armor and bulk slow you down.
    const speedScale = 0.55 + Math.max(1, this.traits.speed || 1) / 10;
    const effectiveMaxVelocity = Math.max(
      2.5,
      Config.MAX_VELOCITY * speedScale * armorDrag * sizeDrag
    );
    const magnitude = Math.sqrt(this.velocity.x ** 2 + this.velocity.y ** 2);
    if (magnitude > effectiveMaxVelocity && magnitude > 0) {
      this.velocity.x = (this.velocity.x / magnitude) * effectiveMaxVelocity;
      this.velocity.y = (this.velocity.y / magnitude) * effectiveMaxVelocity;
    }
  }

  private getSimulationSteps(deltaTime: number): number {
    return Math.max(0, Math.min(10, deltaTime * Config.TARGET_FPS));
  }

  getATPDrainPerSecond(): number {
    return this.getATPDrainPerStep() * Config.TARGET_FPS;
  }

  // Drain ATP based on metabolism, body plan, senses, and combat load.
  private drainATP(simulationSteps: number): void {
    this.traits.atp -= this.getATPDrainPerStep() * simulationSteps;

    // Clamp ATP to valid range
    if (this.traits.atp < 0) {
      this.traits.atp = 0;
      this.onDeath();
    }
    if (this.traits.atp > this.traits.maxATP) {
      this.traits.atp = this.traits.maxATP;
    }
  }

  private getATPDrainPerStep(): number {
    const size = Math.max(1, this.traits.size || 1);
    const speed = Math.max(1, this.traits.speed || 1);
    const armor = Math.max(0, this.traits.armor || 0);
    const visionRange = Math.max(50, this.traits.visionRange || 50);
    const chemotaxis = Math.max(0, this.traits.chemotaxis || 0);
    const hearing = Math.max(0, this.traits.hearing || 0);
    const intelligence = Math.max(0, this.traits.intelligence || 0);
    const aggression = Math.max(0, this.traits.aggression || 0);
    const toxinStrength = Math.max(0, this.traits.toxinStrength || 0);
    const burst = Math.max(0, this.traits.speedBurstPower || 0);
    const regeneration = Math.max(0, this.traits.regeneration || 0);
    const photosynthesis = Math.max(0, this.traits.photosynthesis || 0);

    const baseDrain = Config.ATP_DRAIN_RATE;
    const sizeDrain = size * Config.ATP_DRAIN_MULTIPLIER_SIZE;
    const speedDrain = Math.max(0, speed - 4) * 0.0025;
    const armorDrain = armor * 0.0018;
    const sensoryDrain =
      (Math.max(0, visionRange - 150) / 350) * 0.012 +
      chemotaxis * 0.0009 +
      hearing * 0.0007;
    const cognitionDrain = intelligence * 0.0009;
    const weaponDrain = aggression * 0.0006 + toxinStrength * 0.0012 + burst * 0.0008;
    const regenerationDrain = regeneration * 0.001;
    const photosynthesisCredit = photosynthesis * 0.012;

    const metabolismRate = Math.max(0.5, this.traits.metabolismRate || 1);
    const energyEfficiency = Math.max(0.35, Math.min(1.8, this.traits.energyEfficiency || 1));
    const preEfficiencyDrain = Math.max(
      0.006,
      baseDrain + sizeDrain + speedDrain + armorDrain + sensoryDrain + cognitionDrain + weaponDrain + regenerationDrain - photosynthesisCredit
    );

    return (preEfficiencyDrain * metabolismRate) / energyEfficiency;
  }

  private regenerateHealth(deltaTime: number): void {
    const regenPerSecond = Math.max(0, this.traits.regeneration || 0);
    if (regenPerSecond <= 0 || this.traits.health <= 0) return;

    this.traits.health = Math.min(
      this.traits.maxHealth,
      this.traits.health + regenPerSecond * deltaTime
    );
  }

  // Restore ATP (from glucose collection)
  restoreATP(amount: number): void {
    this.traits.atp += amount;
    if (this.traits.atp > this.traits.maxATP) {
      this.traits.atp = this.traits.maxATP;
    }
  }

  // Keep cell within lake boundaries
  private constrainToLake(): void {
    const halfWidth = Config.LAKE_WIDTH / 2;
    const halfHeight = Config.LAKE_HEIGHT / 2;

    // Bounce off walls instead of getting stuck
    if (this.position.x < -halfWidth) {
      this.position.x = -halfWidth;
      this.velocity.x = Math.abs(this.velocity.x) * 0.5; // Bounce with damping
    }
    if (this.position.x > halfWidth) {
      this.position.x = halfWidth;
      this.velocity.x = -Math.abs(this.velocity.x) * 0.5; // Bounce with damping
    }
    if (this.position.y < -halfHeight) {
      this.position.y = -halfHeight;
      this.velocity.y = Math.abs(this.velocity.y) * 0.5; // Bounce with damping
    }
    if (this.position.y > halfHeight) {
      this.position.y = halfHeight;
      this.velocity.y = -Math.abs(this.velocity.y) * 0.5; // Bounce with damping
    }
  }

  // Handle cell death
  private onDeath(): void {
    if (this.isPlayer && this.deathCallback) {
      // Determine cause of death: if health is 0, it's health damage; otherwise ATP depletion
      const cause: 'atp' | 'health' = this.traits.health <= 0 ? 'health' : 'atp';
      this.deathCallback(cause);
    }
  }

  // Set callback for when cell dies (used for player death screen)
  setDeathCallback(callback: (cause: 'atp' | 'health') => void): void {
    this.deathCallback = callback;
  }

  // Get distance to another position
  distanceTo(target: Vector2D): number {
    const dx = this.position.x - target.x;
    const dy = this.position.y - target.y;
    return Math.sqrt(dx * dx + dy * dy);
  }

  dispose(): void {
    this.sprite.destroy();
  }
}
