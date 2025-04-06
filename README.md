# Aadhaar Extractor 🔍

A Dart-based Aadhaar text extractor for Flutter apps. It extracts key information from scanned Aadhaar OCR text including:

- ✅ Name (supports mixed-case, initials, and all caps)
- 📅 Date of Birth (DOB)
- ⚥ Gender (supports English & Tamil)
- 🔢 Aadhaar Number (supports masked format)
- 📬 Address
- 🗓️ Issue Date

---

## 📦 Features

- Clean and simple API
- Regex-based Aadhaar data extraction
- Handles various name formats (e.g., `K Bhuvaneshwaran`, `K Bhuvan`, `K BHUVANESHWARAN`)
- Supports masked Aadhaar numbers like `XXXX XXXX XXXX`
- Tamil and English gender support
- Lightweight and easy to integrate into Flutter apps

---

## 🧠 How it Works

```mermaid
graph TD
  A[OCR Scanned Text] --> B[Regex Matchers]
  B --> C[Extracted Fields]
  C --> D[Map<String, String?>]
  D --> E[Use in UI / API / Save to DB]
