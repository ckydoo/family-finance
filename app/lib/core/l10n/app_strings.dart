/// Lightweight string lookup for supported app locales (English, Español,
/// Français, Português). Kept intentionally small so it works without codegen;
/// full localization lives in `lib/l10n/app_*.arb` via `gen-l10n`.
const kStrings = <String, Map<String, String>>{
  'en': {
    'tab_home': 'Home',
    'tab_budgets': 'Budgets',
    'tab_plan': 'Plan Ahead',
    'tab_family': 'Family',
    'pool_title': 'Family Pool',
    'safe_to_spend': 'Safe to spend',
    'add': 'Add',
    'save': 'Save',
    'cancel': 'Cancel',
    'settings': 'Settings',
    'language': 'Language',
  },
  'es': {
    'tab_home': 'Inicio',
    'tab_budgets': 'Presupuestos',
    'tab_plan': 'Planificar',
    'tab_family': 'Familia',
    'pool_title': 'Fondo familiar',
    'safe_to_spend': 'Disponible para gastar',
    'add': 'Añadir',
    'save': 'Guardar',
    'cancel': 'Cancelar',
    'settings': 'Ajustes',
    'language': 'Idioma',
  },
  'fr': {
    'tab_home': 'Accueil',
    'tab_budgets': 'Budgets',
    'tab_plan': 'Planifier',
    'tab_family': 'Famille',
    'pool_title': 'Cagnotte familiale',
    'safe_to_spend': 'Disponible à dépenser',
    'add': 'Ajouter',
    'save': 'Enregistrer',
    'cancel': 'Annuler',
    'settings': 'Paramètres',
    'language': 'Langue',
  },
  'pt': {
    'tab_home': 'Início',
    'tab_budgets': 'Orçamentos',
    'tab_plan': 'Planear',
    'tab_family': 'Família',
    'pool_title': 'Fundo familiar',
    'safe_to_spend': 'Disponível para gastar',
    'add': 'Adicionar',
    'save': 'Guardar',
    'cancel': 'Cancelar',
    'settings': 'Definições',
    'language': 'Idioma',
  },
};

const kLanguageNames = {
  'en': 'English',
  'es': 'Español',
  'fr': 'Français',
  'pt': 'Português',
};

/// Normalizes any persisted or server locale code to a currently supported
/// language code, falling back cleanly to English (`'en'`).
String normalizeSupportedLocale(String? code) =>
    (code != null && kLanguageNames.containsKey(code)) ? code : 'en';

String tr(String localeCode, String key) =>
    kStrings[localeCode]?[key] ?? kStrings['en']![key] ?? key;
