"""
This script provides command-line tools for translating text between English and
Dravidian languages (Tamil, Malayalam, Kannada, Telugu) using MarianMT models.

It supports three modes of operation:
1.  en-to-dra: Translate English to a specified Dravidian language.
2.  dra-to-en: Translate Dravidian language text to English.
3.  round-trip: Translate English to a Dravidian language and then back to English.

Usage Examples:

1. Translate English to Tamil:
   python scripts/en_tam_en.py --text "Hello, how are you?" --mode en-to-dra --target-lang tam

2. Translate Tamil to English:
   python scripts/en_tam_en.py --text "வணக்கம், எப்படி இருக்கிறீர்கள்?" --mode dra-to-en

3. Perform round-trip translation (English -> Malayalam -> English):
   python scripts/en_tam_en.py --text "This is a test sentence." --mode round-trip --target-lang mal

4. Get help:
   python scripts/en_tam_en.py --help
"""
from transformers import MarianMTModel, MarianTokenizer
import torch
import argparse

# Check if GPU is available and set device accordingly
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"Using device: {device}")

def translate_en_to_dra(text, target_lang="tam"):
    """
    Translate English text to a Dravidian language
    
    Args:
        text (str): The English text to translate
        target_lang (str): Target language code - 'tam' (Tamil), 'mal' (Malayalam), 
                          'kan' (Kannada), or 'tel' (Telugu)
    
    Returns:
        str: Translated text in the target Dravidian language
    """
    model_name = "Helsinki-NLP/opus-mt-en-dra"
    tokenizer = MarianTokenizer.from_pretrained(model_name)
    model = MarianMTModel.from_pretrained(model_name).to(device)
    
    # Prepend target language token to the source text
    src_text = f">>{target_lang}<< {text}"
    
    # Tokenize the input
    inputs = tokenizer([src_text], return_tensors="pt", padding=True).to(device)
    
    # Generate translation with beam search
    translated = model.generate(
        **inputs,
        num_beams=3,
        early_stopping=True
    )
    
    # Decode the translation
    dra_text = tokenizer.decode(translated[0], skip_special_tokens=True)
    
    return dra_text

def translate_dra_to_en(text):
    """
    Translate Dravidian language text to English
    
    Args:
        text (str): The text in a Dravidian language to translate
    
    Returns:
        str: Translated text in English
    """
    model_name = "Helsinki-NLP/opus-mt-mul-en"
    tokenizer = MarianTokenizer.from_pretrained(model_name)
    model = MarianMTModel.from_pretrained(model_name).to(device)
    
    # Tokenize the input
    inputs = tokenizer([text], return_tensors="pt", padding=True).to(device)
    
    # Generate translation with beam search
    translated = model.generate(
        **inputs,
        num_beams=3,
        early_stopping=True
    )
    
    # Decode the translation
    en_text = tokenizer.decode(translated[0], skip_special_tokens=True)
    
    return en_text

def round_trip_translation(english_text, target_lang="tam"):
    """
    Perform round-trip translation: English -> Dravidian language -> English
    
    Args:
        english_text (str): The English text to translate and back-translate
        target_lang (str): Target Dravidian language code
    
    Returns:
        tuple: (dravidian_text, back_to_english)
    """
    print(f"Original English: {english_text}")
    
    # Map of language codes to names
    lang_names = {
        "tam": "Tamil",
        "mal": "Malayalam",
        "kan": "Kannada",
        "tel": "Telugu"
    }
    
    language_name = lang_names.get(target_lang, target_lang)
    
    # English to Dravidian language
    try:
        dravidian_text = translate_en_to_dra(english_text, target_lang)
        print(f"Translated to {language_name}: {dravidian_text}")
    except Exception as e:
        print(f"Error translating to {language_name}: {str(e)}")
        return None, None
    
    # Dravidian language back to English
    try:
        back_to_english = translate_dra_to_en(dravidian_text)
        print(f"Back to English: {back_to_english}")
    except Exception as e:
        print(f"Error translating back to English: {str(e)}")
        return dravidian_text, None
    
    return dravidian_text, back_to_english

def parse_arguments():
    parser = argparse.ArgumentParser(description='Translate between English and Dravidian languages')
    parser.add_argument('--text', required=True, help='Text to translate')
    parser.add_argument('--mode', choices=['en-to-dra', 'dra-to-en', 'round-trip'],
                       default='round-trip', help='Translation mode (default: round-trip)')
    parser.add_argument('--target-lang', choices=['tam', 'mal', 'kan', 'tel'],
                       default='tam', help="Target Dravidian language for 'en-to-dra' and 'round-trip' modes (default: tam)")
    return parser.parse_args()

if __name__ == "__main__":
    args = parse_arguments()
    
    # Map of language codes to names for printing
    lang_names = {
        "tam": "Tamil",
        "mal": "Malayalam",
        "kan": "Kannada",
        "tel": "Telugu"
    }
    target_language_name = lang_names.get(args.target_lang, args.target_lang)

    if args.mode == 'en-to-dra':
        print(f"Translating English to {target_language_name}...")
        result = translate_en_to_dra(args.text, args.target_lang)
        print(f"Input English: {args.text}")
        print(f"Translated to {target_language_name}: {result}")
    elif args.mode == 'dra-to-en':
        print(f"Translating Dravidian language to English...")
        result = translate_dra_to_en(args.text)
        print(f"Input Dravidian: {args.text}")
        print(f"Translated to English: {result}")
    elif args.mode == 'round-trip':
        print(f"Performing round-trip translation (English -> {target_language_name} -> English)...")
        dravidian_text, back_to_english = round_trip_translation(args.text, args.target_lang)
        # The round_trip_translation function already prints its progress and results
        if dravidian_text is not None and back_to_english is not None:
            print("Round-trip translation completed.")
        else:
            print("Round-trip translation encountered an error.")
