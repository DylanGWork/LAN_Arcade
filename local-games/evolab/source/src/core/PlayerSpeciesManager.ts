// Manages the player's species population and evolution
// Handles species-level operations instead of single organism control

import { Cell } from '../entities/Cell';
import { Resource } from '../entities/Resource';
import { Genome } from '../genetics/Genome';
import { PixiApp } from '../rendering/PixiApp';
import { BiomeGenerator } from '../environment/BiomeGenerator';
import { Config } from './Config';
import { AutoPilot } from './AutoPilot';
import type { Traits } from '../types/entities';
import { logger } from '../utils/Logger';

export interface SpeciesStats {
  population: number;
  averageTraits: Partial<Traits>;
  totalResourcesCollected: number;
  totalBirths: number;
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
  private initialPopulationSize = 15; // Increased for better visibility

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

      const cell = new Cell(`player-species-${i}`, x, y, genome, sprite, false);
      
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

      if (resource.type === 'glucose') {
        const atpBefore = cell.traits.atp;
        cell.restoreATP(Config.ATP_FROM_GLUCOSE);
        cell.collectCompound('glucose', 5);
        const atpGained = cell.traits.atp - atpBefore;
        if (atpGained > 0) {
          this.renderer.particleSystem.createATPText(cell.position.x, cell.position.y, atpGained);
        }
      } else if (resource.type === 'aminoAcid') {
        cell.collectCompound('aminoAcid', 3);
      } else if (resource.type === 'phosphate') {
        cell.collectCompound('phosphate', 2);
      }
    });
  }

  private getResourceColor(type: Resource['type']): number {
    if (type === 'aminoAcid') return Config.AMINO_ACID_COLOR;
    if (type === 'phosphate') return Config.PHOSPHATE_COLOR;
    return Config.GLUCOSE_COLOR;
  }

  // Handle natural reproduction within the species
  private handleNaturalReproduction(reproductionMode: 'asexual' | 'sexual'): void {
    const readyCells = this.cells.filter(cell => cell.canReproduce());
    if (readyCells.length === 0 || this.cells.length >= 50) return;

    if (reproductionMode === 'asexual') {
      for (const parent of readyCells) {
        this.createOffspring(parent);
        if (this.cells.length >= 50) break;
      }
      return;
    }

    const usedParents = new Set<string>();
    for (const parent1 of readyCells) {
      if (usedParents.has(parent1.id)) continue;

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
      if (this.cells.length >= 50) break;
    }
  }

  private createOffspring(parent1: Cell, parent2?: Cell): void {
    const offspringGenome = parent1.genome.clone();
    const mate = parent2 || parent1;

    offspringGenome.traits.size = (parent1.traits.size + mate.traits.size) / 2;
    offspringGenome.traits.speed = (parent1.traits.speed + mate.traits.speed) / 2;
    offspringGenome.traits.maxATP = (parent1.traits.maxATP + mate.traits.maxATP) / 2;
    offspringGenome.traits.maxHealth = (parent1.traits.maxHealth + mate.traits.maxHealth) / 2;
    offspringGenome.traits.color = this.speciesColor;
    offspringGenome.traits.gender = Math.random() < 0.5 ? 'male' : 'female';
    offspringGenome.traits.atp = offspringGenome.traits.maxATP;
    offspringGenome.traits.health = offspringGenome.traits.maxHealth;

    const spawnX = parent2
      ? (parent1.position.x + parent2.position.x) / 2 + (Math.random() - 0.5) * 50
      : parent1.position.x + (Math.random() - 0.5) * 60;
    const spawnY = parent2
      ? (parent1.position.y + parent2.position.y) / 2 + (Math.random() - 0.5) * 50
      : parent1.position.y + (Math.random() - 0.5) * 60;

    const radius = 10 + offspringGenome.traits.size;
    const sprite = this.renderer.createCircle(spawnX, spawnY, radius, offspringGenome.traits.color);
    this.renderer.addToWorld(sprite);

    const offspring = new Cell(
      `player-species-${Date.now()}-${Math.random()}`,
      spawnX,
      spawnY,
      offspringGenome,
      sprite,
      false
    );

    const velocityAngle = Math.random() * Math.PI * 2;
    const speed = 1 + Math.random() * 2;
    offspring.velocity.x = Math.cos(velocityAngle) * speed;
    offspring.velocity.y = Math.sin(velocityAngle) * speed;
    offspring.markReproduction();

    this.spendReproductionCompounds(parent1);
    parent1.markReproduction();
    if (parent2) {
      this.spendReproductionCompounds(parent2);
      parent2.markReproduction();
    }

    this.cells.push(offspring);
    this.totalBirths++;
    this.renderer.particleSystem.createEatingEffect(spawnX, spawnY, this.speciesColor);
  }

  private spendReproductionCompounds(cell: Cell): void {
    cell.compounds.glucose = Math.max(0, cell.compounds.glucose - Config.REPRODUCTION_GLUCOSE_REQUIRED);
    cell.compounds.aminoAcids = Math.max(0, cell.compounds.aminoAcids - Config.REPRODUCTION_AMINO_ACIDS_REQUIRED);
    cell.compounds.phosphates = Math.max(0, cell.compounds.phosphates - Config.REPRODUCTION_PHOSPHATES_REQUIRED);
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
