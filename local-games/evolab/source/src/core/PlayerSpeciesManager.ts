// Manages the player's species population and evolution
// Handles species-level operations instead of single organism control

import { Cell } from '../entities/Cell';
import { Resource } from '../entities/Resource';
import { Genome } from '../genetics/Genome';
import { PixiApp } from '../rendering/PixiApp';
import { BiomeGenerator } from '../environment/BiomeGenerator';
import { Config } from './Config';
import { AutoPilot } from './AutoPilot';
import type { Traits, CompoundStorage } from '../types/entities';
import { logger } from '../utils/Logger';

export interface SpeciesStats {
  population: number;
  averageTraits: Partial<Traits>;
  totalResourcesCollected: number;
  totalBirths: number;
  readyBreeders: number;
  breedingReserve: CompoundStorage;
  averageSurvivalTime: number;
  generation: number;
  diversity: number; // Genetic diversity measure
}

export class PlayerSpeciesManager {
  private cells: Cell[] = [];
  private baseGenome: Genome;
  private renderer: PixiApp;
  private autoPilot: AutoPilot;
  private totalResourcesCollected = 0;
  private totalBirths = 0;
  private generation = 1;
  private speciesColor: number;
  private readonly initialPopulationSize = 15; // Increased for better visibility
  private readonly maxPopulationSize = 60;
  private breedingReserve: CompoundStorage = { glucose: 0, aminoAcids: 0, phosphates: 0 };

  constructor(renderer: PixiApp, biomeGenerator: BiomeGenerator, initialGenome?: Genome) {
    this.renderer = renderer;
    this.baseGenome = initialGenome || Genome.createDefault();
    this.speciesColor = 0x38d5ff;
    this.baseGenome.traits.color = this.speciesColor;
    this.autoPilot = new AutoPilot(biomeGenerator);
  }

  // Initialize the species with starting population
  initialize(): void {
    for (let i = 0; i < this.initialPopulationSize; i++) {
      // Start near the centre so the player species is easy to identify.
      const angle = Math.random() * Math.PI * 2;
      const distance = Math.sqrt(Math.random()) * 180;
      const x = Math.cos(angle) * distance;
      const y = Math.sin(angle) * distance;

      // Create cell with slight genetic variation
      const genome = this.baseGenome.clone();
      // Add small random mutations for diversity
      const mutationAmount = 0.1;
      genome.traits.size += (Math.random() - 0.5) * mutationAmount;
      genome.traits.speed += (Math.random() - 0.5) * mutationAmount;
      genome.traits.color = this.speciesColor;
      genome.traits.gender = Math.random() < 0.5 ? 'male' : 'female';
      
      // Ensure cells start with full ATP and health
      genome.traits.atp = genome.traits.maxATP;
      genome.traits.health = genome.traits.maxHealth;

      const radius = 10 + genome.traits.size;
      const sprite = this.renderer.createCircle(x, y, radius, genome.traits.color);
      this.renderer.addToWorld(sprite);

      const cell = new Cell(`player-species-${i}`, x, y, genome, sprite, true);
      
      // Give cells initial random velocity so they start moving
      const velocityAngle = Math.random() * Math.PI * 2;
      const speed = 1 + Math.random() * 2;
      cell.velocity.x = Math.cos(velocityAngle) * speed;
      cell.velocity.y = Math.sin(velocityAngle) * speed;
      
      // Ensure sprite position matches cell position
      cell.sprite.x = cell.position.x;
      cell.sprite.y = cell.position.y;

      if (Config.DEBUG_PLAYER_SPECIES) {
        logger.log(`[PlayerSpeciesManager] Created cell ${i} at (${x}, ${y}), sprite at (${sprite.x}, ${sprite.y}), radius: ${radius}, color: 0x${genome.traits.color.toString(16)}`);
        logger.log(`[PlayerSpeciesManager] Cell sprite visible: ${sprite.visible}, alpha: ${sprite.alpha}, parent: ${sprite.parent ? 'has parent' : 'no parent'}`);
      }

      this.cells.push(cell);
    }
  }

  // Update all cells in the species
  update(deltaTime: number, allCells: Cell[], resources: Resource[], autoMode: boolean, manualDirection: { x: number; y: number } = { x: 0, y: 0 }, reproductionMode: 'asexual' | 'sexual' = 'asexual'): void {
    // Update each cell
    this.cells.forEach(cell => {
      cell.update(deltaTime);

      // Auto mode lets each cell forage; manual mode applies the keyboard direction
      // to the whole species as a visible herd nudge.
      const otherCells = allCells.filter(c => c.id !== cell.id);
      const manualActive = !autoMode && (manualDirection.x !== 0 || manualDirection.y !== 0);
      const direction = autoMode
        ? this.autoPilot.getMovementDirection(cell, otherCells, resources, deltaTime)
        : manualActive
          ? manualDirection
          : { x: 0, y: 0 };

      const applyCellForce = (dir: { x: number; y: number }, strength: number) => {
        const magnitude = Math.hypot(cell.velocity.x, cell.velocity.y);
        if (magnitude < 0.5) {
          strength *= 1.5;
        }
        cell.applyForce(dir, strength);
      };

      if (direction.x !== 0 || direction.y !== 0) {
        applyCellForce(direction, Config.ACCELERATION * (manualActive ? 2.4 : 1.5));
      } else if (autoMode) {
        const fallbackAngle = (cell.id.charCodeAt(0) + Date.now() * 0.001) % (Math.PI * 2);
        const fallbackDirection = { x: Math.cos(fallbackAngle), y: Math.sin(fallbackAngle) };
        applyCellForce(fallbackDirection, Config.ACCELERATION * 0.75);
      }

      // Check resource collection
      this.checkResourceCollection(cell, resources);
    });

    // Remove dead cells
    this.cells = this.cells.filter(cell => {
      if (cell.traits.atp <= 0 || cell.traits.health <= 0) {
        this.renderer.removeFromWorld(cell.sprite);
        cell.dispose();
        return false;
      }
      return true;
    });

    // Natural reproduction within species
    this.handleNaturalReproduction(reproductionMode);
  }

  // Check resource collection for a cell
  private checkResourceCollection(cell: Cell, resources: Resource[]): void {
    resources.forEach(resource => {
      if (resource.isCollected) return;

      const distance = cell.distanceTo(resource.position);
      if (distance >= Config.RESOURCE_COLLECTION_RANGE) return;

      resource.collect();
      this.autoPilot.clearTarget(cell.id);
      this.totalResourcesCollected++;

      this.renderer.particleSystem.createEatingEffect(
        resource.position.x,
        resource.position.y,
        this.getResourceColor(resource.type)
      );

      const reserveUnits = Math.max(1, Math.round(resource.amount / 5));

      if (resource.type === 'glucose') {
        const atpBefore = cell.traits.atp;
        const atpGain = resource.rarity === 'golden'
          ? Config.ATP_FROM_GLUCOSE * Config.GOLDEN_RESOURCE_DNA_MULTIPLIER
          : Config.ATP_FROM_GLUCOSE;
        cell.restoreATP(atpGain);
        cell.collectCompound('glucose', reserveUnits);
        this.addToBreedingReserve('glucose', reserveUnits);
        const atpGained = cell.traits.atp - atpBefore;
        if (atpGained > 0) {
          this.renderer.particleSystem.createATPText(cell.position.x, cell.position.y, atpGained);
        }
      } else if (resource.type === 'aminoAcid') {
        cell.collectCompound('aminoAcid', reserveUnits);
        this.addToBreedingReserve('aminoAcid', reserveUnits);
      } else if (resource.type === 'phosphate') {
        cell.collectCompound('phosphate', reserveUnits);
        this.addToBreedingReserve('phosphate', reserveUnits);
      }
    });
  }

  private getResourceColor(type: Resource['type']): number {
    if (type === 'aminoAcid') return Config.AMINO_ACID_COLOR;
    if (type === 'phosphate') return Config.PHOSPHATE_COLOR;
    return Config.GLUCOSE_COLOR;
  }

  private addToBreedingReserve(type: Resource['type'], amount: number): void {
    const maxReserve = Math.max(180, this.cells.length * 24);

    if (type === 'glucose') {
      this.breedingReserve.glucose = Math.min(maxReserve, this.breedingReserve.glucose + amount);
    } else if (type === 'aminoAcid') {
      this.breedingReserve.aminoAcids = Math.min(maxReserve, this.breedingReserve.aminoAcids + amount);
    } else if (type === 'phosphate') {
      this.breedingReserve.phosphates = Math.min(maxReserve, this.breedingReserve.phosphates + amount);
    }
  }

  // Handle natural reproduction within the species
  private handleNaturalReproduction(reproductionMode: 'asexual' | 'sexual'): void {
    if (this.cells.length >= this.maxPopulationSize) return;

    const readyCells = this.cells.filter(cell => this.isReadyToBreed(cell));
    if (readyCells.length === 0) return;

    if (reproductionMode === 'asexual') {
      for (const parent of readyCells) {
        if (!this.hasBreedingReserve() || this.cells.length >= this.maxPopulationSize) break;
        this.createOffspring(parent);
      }
      return;
    }

    const usedParents = new Set<string>();
    for (const parent1 of readyCells) {
      if (usedParents.has(parent1.id) || !this.hasBreedingReserve()) continue;

      const parent2 = readyCells.find(candidate =>
        candidate.id !== parent1.id &&
        !usedParents.has(candidate.id) &&
        candidate.traits.gender &&
        parent1.traits.gender &&
        candidate.traits.gender !== parent1.traits.gender
      );

      if (!parent2) continue;

      this.createOffspring(parent1, parent2);
      usedParents.add(parent1.id);
      usedParents.add(parent2.id);
      if (this.cells.length >= this.maxPopulationSize) break;
    }
  }

  private isReadyToBreed(cell: Cell): boolean {
    return this.isPhysicallyReadyToBreed(cell) && this.hasBreedingReserve();
  }

  private isPhysicallyReadyToBreed(cell: Cell): boolean {
    const atpPercent = (cell.traits.atp / cell.traits.maxATP) * 100;
    const healthPercent = cell.traits.maxHealth > 0 ? (cell.traits.health / cell.traits.maxHealth) * 100 : 0;
    const timeSinceLastReproduction = (Date.now() - cell.lastReproductionTime) / 1000;

    return (
      atpPercent >= Config.REPRODUCTION_ATP_THRESHOLD &&
      healthPercent >= 35 &&
      timeSinceLastReproduction >= Config.REPRODUCTION_COOLDOWN_SECONDS
    );
  }

  private hasBreedingReserve(): boolean {
    return (
      this.breedingReserve.glucose >= Config.REPRODUCTION_GLUCOSE_REQUIRED &&
      this.breedingReserve.aminoAcids >= Config.REPRODUCTION_AMINO_ACIDS_REQUIRED &&
      this.breedingReserve.phosphates >= Config.REPRODUCTION_PHOSPHATES_REQUIRED
    );
  }

  private getReadyBreederCount(): number {
    if (!this.hasBreedingReserve()) return 0;
    return this.cells.filter(cell => this.isPhysicallyReadyToBreed(cell)).length;
  }

  private getBreedingReserveSnapshot(): CompoundStorage {
    return { ...this.breedingReserve };
  }

  private createOffspring(parent1: Cell, parent2?: Cell): void {
    const offspringGenome = parent1.genome.clone();
    const mate = parent2 || parent1;

    const inheritedSpeciesId = parent1.genome.lineage.speciesId || this.baseGenome.lineage.speciesId || 'species-001';
    const inheritedColor = parent1.traits.color || this.speciesColor;

    offspringGenome.traits.size = (parent1.traits.size + mate.traits.size) / 2;
    offspringGenome.traits.speed = (parent1.traits.speed + mate.traits.speed) / 2;
    offspringGenome.traits.maxATP = (parent1.traits.maxATP + mate.traits.maxATP) / 2;
    offspringGenome.traits.maxHealth = (parent1.traits.maxHealth + mate.traits.maxHealth) / 2;
    offspringGenome.lineage.speciesId = inheritedSpeciesId;
    offspringGenome.traits.color = inheritedColor;
    offspringGenome.traits.gender = Math.random() < 0.5 ? 'male' : 'female';
    this.applyNaturalMutation(offspringGenome.traits, offspringGenome.lineage.mutations);
    offspringGenome.traits.atp = offspringGenome.traits.maxATP;
    offspringGenome.traits.health = offspringGenome.traits.maxHealth;

    const spawnX = parent2
      ? (parent1.position.x + parent2.position.x) / 2 + (Math.random() - 0.5) * 50
      : parent1.position.x + (Math.random() - 0.5) * 60;
    const spawnY = parent2
      ? (parent1.position.y + parent2.position.y) / 2 + (Math.random() - 0.5) * 50
      : parent1.position.y + (Math.random() - 0.5) * 60;

    const radius = 10 + offspringGenome.traits.size;
    const sprite = this.renderer.createCircle(spawnX, spawnY, radius, inheritedColor);
    this.renderer.addToWorld(sprite);

    const offspring = new Cell(
      `player-species-${Date.now()}-${Math.random()}`,
      spawnX,
      spawnY,
      offspringGenome,
      sprite,
      true
    );

    const velocityAngle = Math.random() * Math.PI * 2;
    const speed = 1 + Math.random() * 2;
    offspring.velocity.x = Math.cos(velocityAngle) * speed;
    offspring.velocity.y = Math.sin(velocityAngle) * speed;
    offspring.markReproduction();

    this.spendReproductionCompounds();
    parent1.markReproduction();
    if (parent2) {
      parent2.markReproduction();
    }

    this.cells.push(offspring);
    this.totalBirths++;
    this.renderer.particleSystem.createEatingEffect(spawnX, spawnY, inheritedColor);
  }

  private applyNaturalMutation(traits: Traits, mutationLog: string[]): void {
    const drift = (key: keyof Traits, min: number, max: number, amount: number, chance = 0.45) => {
      const currentValue = traits[key];
      if (typeof currentValue !== 'number' || Math.random() > chance) return;

      const direction = Math.random() < 0.5 ? -1 : 1;
      const magnitude = amount * (0.5 + Math.random());
      const nextValue = Math.max(min, Math.min(max, currentValue + direction * magnitude));
      (traits[key] as number) = Number(nextValue.toFixed(amount < 1 ? 2 : 1));
      mutationLog.push(`${String(key)} ${direction > 0 ? '+' : '-'}${magnitude.toFixed(2)}`);
    };

    drift('size', 1, 10, 0.35);
    drift('speed', 1, 10, 0.4);
    drift('armor', 0, 10, 0.35);
    drift('regeneration', 0, 5, 0.22);
    drift('visionRange', 50, 500, 18, 0.5);
    drift('chemotaxis', 0, 10, 0.4);
    drift('hearing', 0, 10, 0.35);
    drift('aggression', 0, 10, 0.45);
    drift('intelligence', 0, 10, 0.35);
    drift('fearResponse', 0, 10, 0.45);
    drift('toxinStrength', 0, 10, 0.28);
    drift('speedBurstPower', 0, 10, 0.32);
    drift('camouflage', 0, 10, 0.28);
    drift('photosynthesis', 0, 1, 0.05, 0.28);
    drift('temperatureTolerance', 0, 10, 0.32);
    drift('pressureResistance', 0, 10, 0.28);
    drift('toxinResistance', 0, 10, 0.3);
  }

  private spendReproductionCompounds(): void {
    this.breedingReserve.glucose = Math.max(0, this.breedingReserve.glucose - Config.REPRODUCTION_GLUCOSE_REQUIRED);
    this.breedingReserve.aminoAcids = Math.max(0, this.breedingReserve.aminoAcids - Config.REPRODUCTION_AMINO_ACIDS_REQUIRED);
    this.breedingReserve.phosphates = Math.max(0, this.breedingReserve.phosphates - Config.REPRODUCTION_PHOSPHATES_REQUIRED);
  }

  // Apply evolution modifications to the whole species
  applyEvolution(modifications: Partial<Traits>): void {
    this.generation++;
    const dnaCost = this.calculateEvolutionCost(modifications);
    
    // Update base genome
    Object.assign(this.baseGenome.traits, modifications);
    this.baseGenome.lineage.generation = this.generation;
    this.baseGenome.dnaPoints = Math.max(0, this.baseGenome.dnaPoints - dnaCost);
    
    // Apply selected evolution immediately so the controls match what the player sees.
    this.cells.forEach(cell => {
      Object.keys(modifications).forEach(key => {
        const traitKey = key as keyof Traits;
        const newValue = modifications[traitKey];
        if (newValue !== undefined && typeof newValue === 'number') {
          (cell.traits[traitKey] as number) = newValue;
        }
      });
      cell.genome.traits = cell.traits;
    });
  }

  private calculateEvolutionCost(modifications: Partial<Traits>): number {
    let cost = 0;
    for (const [key, value] of Object.entries(modifications)) {
      const oldValue = this.baseGenome.traits[key as keyof Traits];
      if (typeof value === 'number' && typeof oldValue === 'number') {
        cost += Math.abs(value - oldValue) * Config.DNA_COST_PER_TRAIT_CHANGE;
      }
    }
    return Number(cost.toFixed(2));
  }

  // Get species statistics
  getStats(): SpeciesStats {
    if (this.cells.length === 0) {
      return {
        population: 0,
        averageTraits: {},
        totalResourcesCollected: this.totalResourcesCollected,
        totalBirths: this.totalBirths,
        readyBreeders: 0,
        breedingReserve: this.getBreedingReserveSnapshot(),
        averageSurvivalTime: 0,
        generation: this.generation,
        diversity: 0,
      };
    }

    // Calculate average traits
    const avgTraits: Partial<Traits> = {};
    let totalSurvivalTime = 0;
    const traitValues: { [key: string]: number[] } = {};

    this.cells.forEach(cell => {
      totalSurvivalTime += cell.survivalTime;

      Object.keys(cell.traits).forEach(key => {
        const traitKey = key as keyof Traits;
        const value = cell.traits[traitKey];
        if (typeof value === 'number') {
          if (!traitValues[key]) traitValues[key] = [];
          traitValues[key].push(value);
        }
      });
    });

    Object.keys(traitValues).forEach(key => {
      const values = traitValues[key];
      if (values && values.length > 0) {
        const avg = values.reduce((a, b) => a + b, 0) / values.length;
        const traitKey = key as keyof Traits;
        avgTraits[traitKey] = avg as never; // Use 'never' for partial trait assignment
      }
    });

    // Calculate diversity (standard deviation of traits)
    let diversity = 0;
    Object.keys(traitValues).forEach(key => {
      const values = traitValues[key];
      if (values && values.length > 0) {
        const avg = values.reduce((a, b) => a + b, 0) / values.length;
        const variance = values.reduce((sum, val) => sum + Math.pow(val - avg, 2), 0) / values.length;
        diversity += Math.sqrt(variance);
      }
    });
    diversity /= Object.keys(traitValues).length;

    return {
      population: this.cells.length,
      averageTraits: avgTraits,
      totalResourcesCollected: this.totalResourcesCollected,
      totalBirths: this.totalBirths,
      readyBreeders: this.getReadyBreederCount(),
      breedingReserve: this.getBreedingReserveSnapshot(),
      averageSurvivalTime: totalSurvivalTime / this.cells.length,
      generation: this.generation,
      diversity,
    };
  }

  // Get center position of species (for camera)
  getCenterPosition(): { x: number; y: number } {
    if (this.cells.length === 0) {
      return { x: Config.PLAYER_START_X, y: Config.PLAYER_START_Y };
    }

    // Filter out dead cells
    const aliveCells = this.cells.filter(cell => cell.traits.atp > 0 && cell.traits.health > 0);
    if (aliveCells.length === 0) {
      return { x: Config.PLAYER_START_X, y: Config.PLAYER_START_Y };
    }

    const sumX = aliveCells.reduce((sum, cell) => sum + cell.position.x, 0);
    const sumY = aliveCells.reduce((sum, cell) => sum + cell.position.y, 0);
    
    return {
      x: sumX / aliveCells.length,
      y: sumY / aliveCells.length,
    };
  }

  // Get all cells in the species
  getAllCells(): Cell[] {
    return this.cells;
  }

  // Get base genome
  getBaseGenome(): Genome {
    return this.baseGenome;
  }

  // Check if species is extinct
  isExtinct(): boolean {
    return this.cells.length === 0;
  }

  // Dispose of all cells
  dispose(): void {
    this.cells.forEach(cell => {
      this.renderer.removeFromWorld(cell.sprite);
      cell.dispose();
    });
    this.cells = [];
  }
}
