export type Slot = 'top' | 'bottom' | 'outerwear' | 'footwear' | 'accessory';

export interface Garment {
  id: string;
  name: string;
  /** Which slots this piece fills. A dress covers both top and bottom. */
  covers: Slot[];
  /** OKLCH hue angle of the dominant colour, 0-360. */
  hue: number;
  /** OKLCH chroma. Near zero means a neutral, which goes with anything. */
  chroma: number;
  pattern: 'solid' | 'striped' | 'checked' | 'floral' | 'graphic' | 'other';
  /** 1 loungewear ... 5 black tie. */
  formality: number;
  /** 1 vest ... 5 parka. Drives the weather filter. */
  warmth: number;
  waterproof?: boolean;
  timesWorn: number;
  lastWornISO?: string;
}

export interface Conditions {
  temperatureF: number;
  raining?: boolean;
  /** Target formality. An outfit is judged against where it is going. */
  occasionFormality?: number;
}

export interface Outfit {
  pieces: Garment[];
  score: number;
  /** Why it scored what it did — surfaced in the UI and used in tests. */
  reasons: string[];
}
