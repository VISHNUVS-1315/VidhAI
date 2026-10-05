export type FlowCategory =
  | 'telephony'
  | 'stt'
  | 'reasoning'
  | 'services'
  | 'tts'
  | 'infrastructure';

export interface ProviderItem {
  name: string;
  role: string;
  isPrimary?: boolean;
}

export interface TelecomStepData {
  id: string; // e.g., '01', '02', etc.
  number: string;
  stageName: string;
  shortTitle: string;
  actor: string;
  summary: string;
  details: string[];
  branching?: {
    label: string;
    action: string;
  }[];
  providers: ProviderItem[];
  category: FlowCategory;
  technicalBadge: string;
  relatedTechIds: string[];
}

export interface TelecomTechnology {
  id: string;
  name: string;
  category:
    | 'Telephony & Streaming'
    | 'Speech-to-Text'
    | 'Conversational AI'
    | 'Voice Synthesis'
    | 'Connected Services'
    | 'Core Runtime & Cloud';
  purpose: string; // Exactly one clear, informative sentence
  badge: string;
}
