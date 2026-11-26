#!/usr/bin/env python3
"""Adds the #1/#2 localization keys to all 4 ARB files and regenerates the
hand-maintained gen-l10n output shape (abstract getters + locale impls)."""
import json
import re
from pathlib import Path

APP = Path(__file__).resolve().parent.parent
L10N = APP / 'lib' / 'l10n'
GEN = APP / 'lib' / 'l10n' / 'generated'

KEYS = {
    'householdTimezone': {
        'en': 'Household timezone',
        'es': 'Zona horaria del hogar',
        'fr': 'Fuseau horaire du foyer',
        'pt': 'Fuso horário do agregado',
    },
    'householdTimezoneSub': {
        'en': "Payday cycles roll over at midnight in this timezone — the same budget dates for family at home and abroad",
        'es': "Los ciclos de pago cambian a la medianoche en esta zona horaria: las mismas fechas de presupuesto para la familia en casa y en el extranjero",
        'fr': "Les cycles de paie basculent à minuit dans ce fuseau horaire — les mêmes dates de budget pour la famille au pays et à l'étranger",
        'pt': "Os ciclos de pagamento viram à meia-noite neste fuso horário — as mesmas datas de orçamento para a família em casa e no estrangeiro",
    },
    'receiptPhoto': {
        'en': 'Receipt photo',
        'es': 'Foto del recibo',
        'fr': 'Photo du reçu',
        'pt': 'Foto do recibo',
    },
    'receiptSavedToCloud': {
        'en': 'Synced to the family cloud',
        'es': 'Sincronizada con la nube familiar',
        'fr': 'Synchronisée avec le cloud familial',
        'pt': 'Sincronizada com a nuvem da família',
    },
    'receiptWaitingUpload': {
        'en': "Will upload when you're back online",
        'es': 'Se subirá cuando vuelvas a tener conexión',
        'fr': "Sera envoyée à votre retour en ligne",
        'pt': 'Será enviada quando voltar a ter ligação',
    },
    'receiptOnThisDevice': {
        'en': 'Saved on this device',
        'es': 'Guardada en este dispositivo',
        'fr': 'Enregistrée sur cet appareil',
        'pt': 'Guardada neste dispositivo',
    },
    'receiptLoadFailed': {
        'en': 'Could not load this receipt photo',
        'es': 'No se pudo cargar esta foto del recibo',
        'fr': 'Impossible de charger cette photo de reçu',
        'pt': 'Não foi possível carregar esta foto do recibo',
    },
    'receiptCameraButton': {
        'en': 'Camera',
        'es': 'Cámara',
        'fr': 'Appareil photo',
        'pt': 'Câmara',
    },
    'receiptGalleryButton': {
        'en': 'Gallery',
        'es': 'Galería',
        'fr': 'Galerie',
        'pt': 'Galeria',
    },
    'receiptAdded': {
        'en': 'Receipt added',
        'es': 'Recibo añadido',
        'fr': 'Reçu ajouté',
        'pt': 'Recibo adicionado',
    },
    'removeReceipt': {
        'en': 'Remove receipt',
        'es': 'Quitar recibo',
        'fr': 'Retirer le reçu',
        'pt': 'Remover recibo',
    },
    'cameraUnavailable': {
        'en': 'Camera unavailable. Check camera permission and try again.',
        'es': 'Cámara no disponible. Revisa el permiso de cámara e inténtalo de nuevo.',
        'fr': "Appareil photo indisponible. Vérifiez l'autorisation de l'appareil photo et réessayez.",
        'pt': 'Câmara indisponível. Verifique a permissão da câmara e tente novamente.',
    },
}

LANGS = ['en', 'es', 'fr', 'pt']

# 1. ARB files -------------------------------------------------------------
for lang in LANGS:
    path = L10N / f'app_{lang}.arb'
    data = json.loads(path.read_text(encoding='utf-8'))
    for key, values in KEYS.items():
        data[key] = values[lang]
    path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + '\n',
        encoding='utf-8',
    )
    print(f'arb app_{lang}.arb updated')

# 2. Abstract getters in app_localizations.dart -----------------------------
base = GEN / 'app_localizations.dart'
text = base.read_text(encoding='utf-8')
getters = []
for key, values in KEYS.items():
    getters.append(
        f"  /// No description provided for @{key}.\n"
        f"  ///\n"
        f"  /// In en, this message translates to:\n"
        f"  /// **'{values['en']}'**\n"
        f"  String get {key};\n"
    )
insertion = '\n' + '\n'.join(getters)
# Insert before the closing brace of the AppLocalizations abstract class
# (the last `}` in the file before the delegate class).
marker = 'String get askMhuriFollowUpLabel;\n}'
if marker not in text:
    raise SystemExit('abstract class tail marker not found')
text = text.replace(marker, marker[:-1] + insertion + '}')
base.write_text(text, encoding='utf-8')
print('generated app_localizations.dart updated')

# 3. Locale implementations -------------------------------------------------
for lang in LANGS:
    path = GEN / f'app_localizations_{lang}.dart'
    text = path.read_text(encoding='utf-8')
    impls = []
    for key, values in KEYS.items():
        value = values[lang].replace("'", r"\'")
        impls.append(f"  @override\n  String get {key} => '{value}';\n")
    insertion = '\n' + '\n'.join(impls)
    idx = text.rstrip().rfind('\n}')
    if idx < 0:
        raise SystemExit(f'closing brace not found in {path}')
    text = text[:idx] + insertion + text[idx:]
    path.write_text(text, encoding='utf-8')
    print(f'generated app_localizations_{lang}.dart updated')

print('done')
