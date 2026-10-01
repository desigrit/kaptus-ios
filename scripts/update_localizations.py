#!/usr/bin/env python3
"""Collect new native English copy without changing existing translations."""
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
catalog = root / "Kaptus/Resources/Localizable.xcstrings"
data = json.loads(catalog.read_text(encoding="utf-8"))
patterns = [
    r'(?:Text|Button|Label|Picker|ProgressView|Section|navigationTitle|accessibilityLabel)\("((?:\\.|[^"\\])*)"',
    r'String\(localized:\s*"((?:\\.|[^"\\])*)"',
    r'case \.manual\("((?:\\.|[^"\\])*)"',
    r'return \.manual\("((?:\\.|[^"\\])*)"',
]
for path in list((root / "Kaptus").rglob("*.swift")) + list((root / "Packages/KaptusCore/Sources").rglob("*.swift")):
    text = path.read_text(encoding="utf-8")
    for pattern in patterns:
        for match in re.finditer(pattern, text):
            raw = match.group(1)
            # Swift interpolations are added explicitly to keep printf placeholder types correct.
            if "\\(" in raw:
                continue
            value = raw.replace('\\n', '\n').replace('\\\"', '"').replace('\\\\', '\\')
            if "\u2014" in value:
                raise ValueError("Public copy must not contain an em dash")
            data["strings"].setdefault(value, {"localizations": {"en": {"stringUnit": {"state": "translated", "value": value}}}})
for value in [
    "%lld saved", "%lld% downloaded",
    "Up to %lld provider downloads: display captions and any matching helper.",
    "Up to %lld provider downloads. Saved files are reused. Manual captions work offline; auto-seek also requires a ready model and supported language pair."
]:
    data["strings"].setdefault(value, {"localizations": {"en": {"stringUnit": {"state": "translated", "value": value}}}})
catalog.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"Catalog contains {len(data['strings'])} source strings")
