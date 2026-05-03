# 📖 Quran App Assets Repository

This repository hosts the dynamic assets for the Tajweed Quran Application. It is designed to provide high-quality fonts, audio recitation metadata, and multi-source tafsir data on-demand to minimize the initial application size.

## 📂 Repository Structure

```text
.
├── fonts/                  # Quranic Page Fonts (p1.ttf - p604.ttf)
├── reciters/               # Recitation metadata & timing
│   ├── [reciter-id]/       
│   │   ├── surah.json      # Audio URLs and durations
│   │   └── segments.json   # Word-by-word/Ayah-by-ayah timing
└── tafsirs/                # Multi-language Tafsir & I'rab
    ├── list.json           # Catalog of all available tafsirs
    └── [tafsir-id]/        
        └── data.json       # Content mapped by "surah:ayah"
