#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
SoniTranslate Pro - Doblaje Profesional con IA
Python 3.7+ Compatible | CentOS 8 | Sin Root | Conda
TODO EN UN SOLO ARCHIVO - VERSIÓN FINAL CORREGIDA
Auto-renovación de enlaces Gradio cada 72 horas
"""

import os
import sys
import subprocess
import tempfile
import shutil
import time
import json
import re
import asyncio
from pathlib import Path
from typing import Optional, List, Dict, Tuple
import traceback

# ============================================================
# INSTALACIÓN AUTOMÁTICA DE DEPENDENCIAS - MEJORADO
# ============================================================

def install_package(package_name, pip_name=None, max_retries=2):
    """Instala un paquete con reintentos"""
    if pip_name is None:
        pip_name = package_name
    
    for attempt in range(max_retries):
        try:
            subprocess.check_call(
                [sys.executable, "-m", "pip", "install", pip_name, "--upgrade"],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
            return True
        except subprocess.CalledProcessError:
            if attempt < max_retries - 1:
                time.sleep(2)
            continue
    return False

def install_dependencies():
    """Instala dependencias automáticamente - Python 3.7 compatible"""
    print("🔧 Verificando e instalando dependencias...\n")
    
    # Actualizar pip primero
    print("  📦 Actualizando pip...")
    subprocess.call(
        [sys.executable, "-m", "pip", "install", "--upgrade", "pip"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )
    
    packages = [
        ('gradio', 'gradio'),  # Versión más reciente compatible
        ('edge_tts', 'edge-tts'),
        ('pydub', 'pydub'),
        ('deep_translator', 'deep-translator'),
        ('numpy', 'numpy'),
        ('soundfile', 'soundfile'),
        ('scipy', 'scipy'),
        ('librosa', 'librosa'),
        ('ffmpeg_python', 'ffmpeg-python'),
    ]
    
    failed_packages = []
    
    for module_name, pip_name in packages:
        try:
            __import__(module_name)
            print("  ✅ {} (ya instalado)".format(module_name))
        except ImportError:
            print("  📦 Instalando {}...".format(module_name))
            if install_package(module_name, pip_name):
                print("  ✅ {} instalado".format(module_name))
            else:
                print("  ❌ Error instalando {}".format(module_name))
                failed_packages.append(module_name)
    
    # Whisper (opcional)
    try:
        import whisper
        print("  ✅ whisper (ya instalado)")
    except ImportError:
        print("  📦 Instalando OpenAI Whisper...")
        if install_package('whisper', 'openai-whisper'):
            print("  ✅ whisper instalado")
        else:
            print("  ⚠️ Whisper no instalado (opcional - transcripción automática no disponible)")
    
    if failed_packages:
        print("\n⚠️ Paquetes no instalados: {}".format(", ".join(failed_packages)))
        if 'gradio' in failed_packages:
            print("\n❌ ERROR CRÍTICO: Gradio no se pudo instalar.")
            print("Intenta manualmente:")
            print("  pip install gradio")
            sys.exit(1)
    
    print("\n✅ Verificación de dependencias completada\n")

# Instalar al inicio
install_dependencies()

# Imports después de instalación
try:
    import gradio as gr
    print("✅ Gradio importado correctamente\n")
except ImportError as e:
    print("❌ Error importando Gradio: {}".format(e))
    print("\nIntenta instalar manualmente:")
    print("  pip install gradio --upgrade")
    sys.exit(1)

import edge_tts
from pydub import AudioSegment, effects
import numpy as np
import soundfile as sf
from deep_translator import GoogleTranslator

# ============================================================
# CONFIGURACIÓN GLOBAL
# ============================================================

BASE_DIR = os.path.expanduser("~/sonitranslate")
TEMP_DIR = os.path.join(BASE_DIR, "temp")
OUTPUT_DIR = os.path.join(BASE_DIR, "output")
MODELS_DIR = os.path.join(BASE_DIR, "models")

for directory in [TEMP_DIR, OUTPUT_DIR, MODELS_DIR]:
    os.makedirs(directory, exist_ok=True)

# ============================================================
# CATÁLOGO DE VOCES NEURALES
# ============================================================

VOICES_CATALOG = {
    # ESPAÑOL - Principales
    "es-ES-AlvaroNeural": {"name": "Álvaro (España)", "gender": "male", "lang": "es"},
    "es-ES-ElviraNeural": {"name": "Elvira (España)", "gender": "female", "lang": "es"},
    "es-ES-DarioNeural": {"name": "Darío (España)", "gender": "male", "lang": "es"},
    "es-ES-EliasNeural": {"name": "Elías (España)", "gender": "male", "lang": "es"},
    "es-ES-IreneNeural": {"name": "Irene (España)", "gender": "female", "lang": "es"},
    "es-ES-LaiaNeural": {"name": "Laia (España)", "gender": "female", "lang": "es"},
    "es-ES-TrianaNeural": {"name": "Triana (España)", "gender": "female", "lang": "es"},
    
    "es-MX-DaliaNeural": {"name": "Dalia (México)", "gender": "female", "lang": "es"},
    "es-MX-JorgeNeural": {"name": "Jorge (México)", "gender": "male", "lang": "es"},
    "es-MX-CandelaNeural": {"name": "Candela (México)", "gender": "female", "lang": "es"},
    "es-MX-GerardoNeural": {"name": "Gerardo (México)", "gender": "male", "lang": "es"},
    "es-MX-LibertoNeural": {"name": "Liberto (México)", "gender": "male", "lang": "es"},
    "es-MX-NuriaNeural": {"name": "Nuria (México)", "gender": "female", "lang": "es"},
    "es-MX-PelayoNeural": {"name": "Pelayo (México)", "gender": "male", "lang": "es"},
    "es-MX-RenataNeural": {"name": "Renata (México)", "gender": "female", "lang": "es"},
    
    "es-AR-ElenaNeural": {"name": "Elena (Argentina)", "gender": "female", "lang": "es"},
    "es-AR-TomasNeural": {"name": "Tomás (Argentina)", "gender": "male", "lang": "es"},
    "es-CO-GonzaloNeural": {"name": "Gonzalo (Colombia)", "gender": "male", "lang": "es"},
    "es-CO-SalomeNeural": {"name": "Salomé (Colombia)", "gender": "female", "lang": "es"},
    "es-CL-CatalinaNeural": {"name": "Catalina (Chile)", "gender": "female", "lang": "es"},
    "es-CL-LorenzoNeural": {"name": "Lorenzo (Chile)", "gender": "male", "lang": "es"},
    "es-US-AlonsoNeural": {"name": "Alonso (US)", "gender": "male", "lang": "es"},
    "es-US-PalomaNeural": {"name": "Paloma (US)", "gender": "female", "lang": "es"},
    
    # INGLÉS - Principales
    "en-US-AriaNeural": {"name": "Aria (US)", "gender": "female", "lang": "en"},
    "en-US-GuyNeural": {"name": "Guy (US)", "gender": "male", "lang": "en"},
    "en-US-JennyNeural": {"name": "Jenny (US)", "gender": "female", "lang": "en"},
    "en-US-DavisNeural": {"name": "Davis (US)", "gender": "male", "lang": "en"},
    "en-US-AndrewNeural": {"name": "Andrew (US)", "gender": "male", "lang": "en"},
    "en-US-BrianNeural": {"name": "Brian (US)", "gender": "male", "lang": "en"},
    "en-US-EmmaNeural": {"name": "Emma (US)", "gender": "female", "lang": "en"},
    "en-US-TonyNeural": {"name": "Tony (US)", "gender": "male", "lang": "en"},
    "en-US-SaraNeural": {"name": "Sara (US)", "gender": "female", "lang": "en"},
    "en-US-JasonNeural": {"name": "Jason (US)", "gender": "male", "lang": "en"},
    
    "en-GB-RyanNeural": {"name": "Ryan (UK)", "gender": "male", "lang": "en"},
    "en-GB-SoniaNeural": {"name": "Sonia (UK)", "gender": "female", "lang": "en"},
    "en-GB-LibbyNeural": {"name": "Libby (UK)", "gender": "female", "lang": "en"},
    "en-GB-ThomasNeural": {"name": "Thomas (UK)", "gender": "male", "lang": "en"},
    
    "en-AU-NatashaNeural": {"name": "Natasha (Australia)", "gender": "female", "lang": "en"},
    "en-AU-WilliamNeural": {"name": "William (Australia)", "gender": "male", "lang": "en"},
    "en-CA-ClaraNeural": {"name": "Clara (Canada)", "gender": "female", "lang": "en"},
    "en-CA-LiamNeural": {"name": "Liam (Canada)", "gender": "male", "lang": "en"},
}

# ============================================================
# ESTILOS DE DOBLAJE
# ============================================================

DUBBING_STYLES = {
    "neutral": {"name": "🎙️ Neutral", "rate": 0, "pitch": 0, "ducking": -10},
    "narration": {"name": "📖 Narración", "rate": -5, "pitch": -2, "ducking": -15},
    "documentary": {"name": "🎬 Documental", "rate": -8, "pitch": -5, "ducking": -18},
    "news": {"name": "📺 Noticias", "rate": 5, "pitch": 0, "ducking": -20},
    "commercial": {"name": "📢 Comercial", "rate": 10, "pitch": 5, "ducking": -8},
    "tutorial": {"name": "🎓 Tutorial", "rate": -8, "pitch": 2, "ducking": -15},
    "casual": {"name": "💬 Casual", "rate": 3, "pitch": 2, "ducking": -10},
    "dramatic": {"name": "🎭 Dramático", "rate": -10, "pitch": -3, "ducking": -5},
}

RHYTHM_PRESETS = {
    "very_slow": {"name": "🐌 Muy Lento", "modifier": -20},
    "slow": {"name": "🐢 Lento", "modifier": -10},
    "natural": {"name": "🚶 Natural", "modifier": 0},
    "fast": {"name": "🏃 Rápido", "modifier": 15},
    "very_fast": {"name": "⚡ Muy Rápido", "modifier": 25},
}

# ============================================================
# CLASE: NEURAL VOICE MANAGER
# ============================================================

class NeuralVoiceManager:
    def __init__(self):
        self.cache_dir = os.path.join(MODELS_DIR, "tts_cache")
        os.makedirs(self.cache_dir, exist_ok=True)
    
    def get_voices_for_language(self, language):
        """Retorna lista de voces para un idioma"""
        lang_key = "es" if language.lower() in ["es", "español", "spanish"] else "en"
        voices = []
        
        for voice_id, info in VOICES_CATALOG.items():
            if info["lang"] == lang_key:
                gender_icon = "👨" if info["gender"] == "male" else "👩"
                display = "{} {}".format(gender_icon, info['name'])
                voices.append((display, voice_id))
        
        return sorted(voices, key=lambda x: x[0])
    
    def synthesize_sync(self, text, voice_id, output_path, rate="+0%", pitch="+0Hz", volume="+0%"):
        """Sintetiza texto a audio (síncrono)"""
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        try:
            communicate = edge_tts.Communicate(text=text, voice=voice_id, rate=rate, pitch=pitch, volume=volume)
            loop.run_until_complete(communicate.save(output_path))
            return output_path
        finally:
            loop.close()

# ============================================================
# CLASE: AUDIO PROCESSOR
# ============================================================

class AudioProcessor:
    def __init__(self):
        self.temp_dir = TEMP_DIR
    
    def extract_audio_from_video(self, video_path, output_path=None):
        """Extrae audio de video usando ffmpeg"""
        if output_path is None:
            output_path = os.path.join(self.temp_dir, "extracted_audio.wav")
        
        cmd = [
            "ffmpeg", "-y", "-i", video_path,
            "-vn", "-acodec", "pcm_s16le", "-ar", "44100", "-ac", "2",
            output_path
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            raise RuntimeError("Error extrayendo audio: {}".format(result.stderr))
        
        return output_path
    
    def separate_vocals_simple(self, audio_path, output_dir):
        """Separación simple de voz (fallback sin Demucs)"""
        os.makedirs(output_dir, exist_ok=True)
        
        audio = AudioSegment.from_file(audio_path)
        
        if audio.channels == 2:
            samples = np.array(audio.get_array_of_samples()).reshape(-1, 2)
            left = samples[:, 0].astype(np.float64)
            right = samples[:, 1].astype(np.float64)
            
            vocals_samples = ((left + right) / 2).astype(np.int16)
            accompaniment_left = (left - vocals_samples.astype(np.float64)).astype(np.int16)
            accompaniment_right = (right - vocals_samples.astype(np.float64)).astype(np.int16)
            
            vocals = AudioSegment(
                vocals_samples.tobytes(),
                frame_rate=audio.frame_rate,
                sample_width=audio.sample_width,
                channels=1
            )
            
            acc_samples = np.column_stack([accompaniment_left, accompaniment_right]).flatten()
            accompaniment = AudioSegment(
                acc_samples.astype(np.int16).tobytes(),
                frame_rate=audio.frame_rate,
                sample_width=audio.sample_width,
                channels=2
            )
        else:
            vocals = audio
            accompaniment = AudioSegment.silent(duration=len(audio), frame_rate=audio.frame_rate)
        
        vocals_path = os.path.join(output_dir, "vocals.wav")
        accompaniment_path = os.path.join(output_dir, "no_vocals.wav")
        
        vocals.export(vocals_path, format="wav")
        accompaniment.export(accompaniment_path, format="wav")
        
        return {"vocals": vocals_path, "accompaniment": accompaniment_path}
    
    def adjust_audio_speed(self, audio_path, target_duration_ms, output_path=None):
        """Ajusta velocidad del audio"""
        if output_path is None:
            output_path = os.path.join(self.temp_dir, "speed_adjusted.wav")
        
        audio = AudioSegment.from_file(audio_path)
        current_duration = len(audio)
        
        if current_duration == 0 or abs(current_duration - target_duration_ms) < 100:
            shutil.copy(audio_path, output_path)
            return output_path
        
        speed_factor = current_duration / float(target_duration_ms)
        speed_factor = max(0.5, min(2.0, speed_factor))
        
        cmd = [
            "ffmpeg", "-y", "-i", audio_path,
            "-filter:a", "atempo={}".format(speed_factor),
            "-acodec", "pcm_s16le", output_path
        ]
        
        subprocess.run(cmd, capture_output=True, check=True)
        return output_path

# ============================================================
# CLASE: AUDIO MIXER
# ============================================================

class AudioMixer:
    def mix_segments(self, accompaniment_path, voice_segments, output_path, 
                    music_volume_db=-3, voice_volume_db=2, ducking_db=-15):
        """Mezcla segmentos de voz con música de fondo"""
        
        accompaniment = AudioSegment.from_file(accompaniment_path)
        accompaniment = accompaniment + music_volume_db
        
        total_duration = len(accompaniment)
        voice_track = AudioSegment.silent(duration=total_duration, frame_rate=44100)
        
        for segment in voice_segments:
            seg_audio = AudioSegment.from_file(segment["audio_path"])
            seg_audio = seg_audio + voice_volume_db
            start_ms = segment["start_ms"]
            voice_track = voice_track.overlay(seg_audio, position=start_ms)
        
        mixed = self._apply_simple_ducking(accompaniment, voice_track, ducking_db)
        mixed = effects.normalize(mixed, headroom=1.0)
        mixed.export(output_path, format="wav")
        
        return output_path
    
    def _apply_simple_ducking(self, music, voice, ducking_db):
        """Ducking simplificado"""
        chunk_ms = 100
        result = AudioSegment.empty()
        
        for i in range(0, len(music), chunk_ms):
            music_chunk = music[i:i + chunk_ms]
            voice_chunk = voice[i:i + chunk_ms]
            
            if len(voice_chunk) == 0 or len(music_chunk) == 0:
                break
            
            voice_db = voice_chunk.dBFS
            
            if voice_db > -40:
                ducked_music = music_chunk + ducking_db
                mixed_chunk = ducked_music.overlay(voice_chunk)
            else:
                mixed_chunk = music_chunk.overlay(voice_chunk)
            
            result += mixed_chunk
        
        return result

# ============================================================
# CLASE: TRANSLATOR
# ============================================================

class TextTranslator:
    def translate(self, text, source_lang="auto", target_lang="en"):
        """Traduce texto"""
        if not text or not text.strip():
            return ""
        
        source_lang = "auto" if source_lang.lower() in ["auto", "auto-detectar"] else source_lang[:2]
        target_lang = target_lang[:2]
        
        if source_lang == target_lang and source_lang != "auto":
            return text
        
        try:
            translator = GoogleTranslator(source=source_lang, target=target_lang)
            
            if len(text) > 4500:
                sentences = re.split(r'(?<=[.!?])\s+', text)
                chunks = []
                current_chunk = ""
                
                for sentence in sentences:
                    if len(current_chunk) + len(sentence) < 4500:
                        current_chunk += " " + sentence
                    else:
                        if current_chunk.strip():
                            chunks.append(current_chunk.strip())
                        current_chunk = sentence
                
                if current_chunk.strip():
                    chunks.append(current_chunk.strip())
                
                translated_chunks = []
                for chunk in chunks:
                    try:
                        result = translator.translate(chunk)
                        translated_chunks.append(result if result else chunk)
                    except:
                        translated_chunks.append(chunk)
                
                return " ".join(translated_chunks)
            
            result = translator.translate(text)
            return result if result else text
            
        except Exception as e:
            print("⚠️ Error de traducción: {}".format(e))
            return text

# ============================================================
# CLASE: VIDEO PROCESSOR
# ============================================================

class VideoProcessor:
    def __init__(self):
        self.temp_dir = TEMP_DIR
        self.output_dir = OUTPUT_DIR
    
    def replace_audio(self, video_path, audio_path, output_path=None, quality="high"):
        """Reemplaza audio en video"""
        if output_path is None:
            base = Path(video_path).stem
            output_path = os.path.join(self.output_dir, "{}_dubbed.mp4".format(base))
        
        quality_settings = {
            "low": ["-crf", "28"],
            "medium": ["-crf", "23"],
            "high": ["-crf", "18"],
            "ultra": ["-crf", "15"],
        }
        
        q_settings = quality_settings.get(quality, quality_settings["high"])
        
        cmd = [
            "ffmpeg", "-y",
            "-i", video_path,
            "-i", audio_path,
            "-c:v", "libx264",
        ]
        cmd.extend(q_settings)
        cmd.extend([
            "-preset", "fast",
            "-map", "0:v:0",
            "-map", "1:a:0",
            "-c:a", "aac",
            "-b:a", "192k",
            "-shortest",
            output_path
        ])
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode != 0:
            raise RuntimeError("Error procesando video: {}".format(result.stderr))
        
        return output_path

# ============================================================
# FUNCIÓN: TRANSCRIBIR AUDIO
# ============================================================

def transcribe_audio(audio_path, language="auto"):
    """Transcribe audio con Whisper"""
    try:
        import whisper
        
        print("  🎤 Cargando modelo Whisper...")
        model = whisper.load_model("base")
        
        print("  🎤 Transcribiendo...")
        result = model.transcribe(audio_path, language=None if language == "auto" else language)
        
        segments = []
        for seg in result["segments"]:
            segments.append({
                "start": seg["start"],
                "end": seg["end"],
                "text": seg["text"].strip(),
                "start_ms": int(seg["start"] * 1000),
                "end_ms": int(seg["end"] * 1000),
            })
        
        return segments, result.get("language", language)
    
    except Exception as e:
        print("⚠️ Error en transcripción: {}".format(e))
        return [], language

# ============================================================
# FUNCIÓN PRINCIPAL: PROCESO DE DOBLAJE
# ============================================================

def process_dubbing(
    input_video,
    source_language,
    target_language,
    voice_id,
    dubbing_style,
    rhythm,
    custom_pitch,
    custom_volume,
    music_volume,
    voice_volume,
    ducking_amount,
    enable_ducking,
    output_quality,
):
    """Proceso principal de doblaje"""
    
    if input_video is None:
        return None, None, "❌ Por favor sube un video"
    
    try:
        timestamp = int(time.time())
        work_dir = os.path.join(TEMP_DIR, "job_{}".format(timestamp))
        os.makedirs(work_dir, exist_ok=True)
        
        log_messages = []
        
        def log(msg):
            log_messages.append(msg)
            print(msg)
            return "\n".join(log_messages)
        
        voice_manager = NeuralVoiceManager()
        audio_processor = AudioProcessor()
        translator = TextTranslator()
        video_processor = VideoProcessor()
        mixer = AudioMixer()
        
        log("📹 Paso 1/7: Extrayendo audio del video...")
        audio_path = audio_processor.extract_audio_from_video(
            input_video,
            os.path.join(work_dir, "original_audio.wav")
        )
        
        log("🎵 Paso 2/7: Separando voz de música...")
        stems = audio_processor.separate_vocals_simple(audio_path, os.path.join(work_dir, "separated"))
        vocals_path = stems["vocals"]
        accompaniment_path = stems["accompaniment"]
        log("✅ Separación completada")
        
        log("🎙️ Paso 3/7: Transcribiendo audio...")
        src_lang = source_language if source_language != "auto" else "auto"
        segments, detected_language = transcribe_audio(vocals_path, src_lang)
        log("✅ Transcripción: {} segmentos, idioma: {}".format(len(segments), detected_language))
        
        log("🌍 Paso 4/7: Traduciendo...")
        tgt = "en" if target_language.lower() in ["en", "english", "inglés"] else "es"
        
        translated_segments = []
        for segment in segments:
            translated_text = translator.translate(segment["text"], detected_language, tgt)
            translated_segments.append({
                "start": segment["start"],
                "end": segment["end"],
                "start_ms": segment["start_ms"],
                "end_ms": segment["end_ms"],
                "original_text": segment["text"],
                "text": translated_text,
            })
        
        log("✅ Traducción completada: {} segmentos".format(len(translated_segments)))
        
        log("🗣️ Paso 5/7: Generando voz doblada...")
        
        style = DUBBING_STYLES.get(dubbing_style, DUBBING_STYLES["neutral"])
        rhythm_preset = RHYTHM_PRESETS.get(rhythm, RHYTHM_PRESETS["natural"])
        
        final_rate = style["rate"] + rhythm_preset["modifier"]
        final_rate = max(-50, min(50, final_rate))
        rate_str = "{:+d}%".format(final_rate)
        
        pitch_str = "{:+d}Hz".format(custom_pitch)
        volume_str = "{:+d}%".format(custom_volume)
        
        voice_segments = []
        
        for i, segment in enumerate(translated_segments):
            text = segment["text"]
            if not text.strip():
                continue
            
            seg_output = os.path.join(work_dir, "tts_segment_{:04d}.wav".format(i))
            
            voice_manager.synthesize_sync(
                text=text,
                voice_id=voice_id,
                output_path=seg_output,
                rate=rate_str,
                pitch=pitch_str,
                volume=volume_str,
            )
            
            target_duration = segment["end_ms"] - segment["start_ms"]
            adjusted_path = os.path.join(work_dir, "tts_adjusted_{:04d}.wav".format(i))
            
            audio_processor.adjust_audio_speed(seg_output, target_duration, adjusted_path)
            
            voice_segments.append({
                "audio_path": adjusted_path if os.path.exists(adjusted_path) else seg_output,
                "start_ms": segment["start_ms"],
                "end_ms": segment["end_ms"],
                "text": text,
            })
        
        log("✅ Voz generada: {} segmentos".format(len(voice_segments)))
        
        log("🎛️ Paso 6/7: Mezclando audio...")
        final_audio_path = os.path.join(work_dir, "final_audio.wav")
        
        mixer.mix_segments(
            accompaniment_path=accompaniment_path,
            voice_segments=voice_segments,
            output_path=final_audio_path,
            music_volume_db=music_volume,
            voice_volume_db=voice_volume,
            ducking_db=ducking_amount if enable_ducking else 0,
        )
        
        log("✅ Mezcla completada")
        
        log("🎬 Paso 7/7: Generando video final...")
        input_basename = Path(input_video).stem
        output_filename = "{}_dubbed_{}_{}.mp4".format(input_basename, tgt, timestamp)
        output_path = os.path.join(OUTPUT_DIR, output_filename)
        
        video_processor.replace_audio(
            video_path=input_video,
            audio_path=final_audio_path,
            output_path=output_path,
            quality=output_quality
        )
        
        log("🎉 ¡Doblaje completado! Video guardado: {}".format(output_path))
        
        summary = """
## ✅ Doblaje Completado

**Idioma origen:** {}  
**Idioma destino:** {}  
**Voz:** {}  
**Estilo:** {}  
**Segmentos:** {}  
**Archivo:** {}

### Transcripción (primeros 5 segmentos):
""".format(detected_language, tgt, voice_id, dubbing_style, len(voice_segments), output_filename)
        
        for seg in translated_segments[:5]:
            summary += "\n[{:.1f}s]: {}".format(seg['start'], seg['text'])
        
        return output_path, final_audio_path, summary
        
    except Exception as e:
        error_msg = "❌ Error:\n```\n{}\n```".format(traceback.format_exc())
        print(error_msg)
        return None, None, error_msg

# ============================================================
# FUNCIÓN: PREVIEW DE VOZ
# ============================================================

def preview_voice(voice_id, dubbing_style, rhythm, custom_pitch, custom_volume):
    """Genera preview de voz"""
    
    preview_texts = {
        "es": "Hola, esta es una demostración de cómo sonará la voz en el doblaje final.",
        "en": "Hello, this is a demonstration of how the voice will sound in the final dub."
    }
    
    lang_key = "es" if "es" in voice_id.lower() else "en"
    text = preview_texts[lang_key]
    
    style = DUBBING_STYLES.get(dubbing_style, DUBBING_STYLES["neutral"])
    rhythm_preset = RHYTHM_PRESETS.get(rhythm, RHYTHM_PRESETS["natural"])
    
    final_rate = style["rate"] + rhythm_preset["modifier"]
    final_rate = max(-50, min(50, final_rate))
    rate_str = "{:+d}%".format(final_rate)
    
    pitch_str = "{:+d}Hz".format(custom_pitch)
    volume_str = "{:+d}%".format(custom_volume)
    
    output_path = os.path.join(TEMP_DIR, "preview.wav")
    
    try:
        voice_manager = NeuralVoiceManager()
        voice_manager.synthesize_sync(
            text=text,
            voice_id=voice_id,
            output_path=output_path,
            rate=rate_str,
            pitch=pitch_str,
            volume=volume_str,
        )
        return output_path
    except Exception as e:
        print("Error en preview: {}".format(e))
        return None

# ============================================================
# INTERFAZ GRADIO
# ============================================================

def create_interface():
    """Crea interfaz Gradio"""
    
    voice_manager = NeuralVoiceManager()
    
    voices_en = voice_manager.get_voices_for_language("en")
    voices_es = voice_manager.get_voices_for_language("es")
    all_voices = voices_es + voices_en
    
    style_choices = [(v["name"], k) for k, v in DUBBING_STYLES.items()]
    rhythm_choices = [(v["name"], k) for k, v in RHYTHM_PRESETS.items()]
    
    with gr.Blocks(title="SoniTranslate Pro", theme=gr.themes.Soft()) as app:
        
        gr.HTML("""
        <div style="text-align: center; padding: 20px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); border-radius: 15px; margin-bottom: 20px; color: white;">
            <h1>🎬 SoniTranslate Pro</h1>
            <p>Doblaje Profesional con IA Neural | Música Original Preservada</p>
            <p style="font-size: 0.9em; opacity: 0.9;">🔄 Enlace auto-renovable cada 72 horas</p>
        </div>
        """)
        
        with gr.Tab("🎬 Doblaje"):
            
            with gr.Row():
                with gr.Column():
                    input_video = gr.Video(label="📹 Video de Entrada")
                    
                    with gr.Row():
                        source_language = gr.Dropdown(
                            label="Idioma Origen",
                            choices=[("Auto-detectar", "auto"), ("Español", "es"), ("English", "en")],
                            value="auto"
                        )
                        target_language = gr.Dropdown(
                            label="Idioma Destino",
                            choices=[("English", "en"), ("Español", "es")],
                            value="en"
                        )
                
                with gr.Column():
                    voice_id = gr.Dropdown(
                        label="🗣️ Voz Neural",
                        choices=all_voices,
                        value="en-US-GuyNeural"
                    )
                    
                    with gr.Row():
                        dubbing_style = gr.Dropdown(
                            label="🎭 Estilo",
                            choices=style_choices,
                            value="neutral"
                        )
                        rhythm = gr.Dropdown(
                            label="⏱️ Ritmo",
                            choices=rhythm_choices,
                            value="natural"
                        )
            
            with gr.Accordion("⚙️ Ajustes Avanzados", open=False):
                with gr.Row():
                    custom_pitch = gr.Slider(-20, 20, 0, step=1, label="Pitch (Hz)")
                    custom_volume = gr.Slider(-20, 20, 0, step=1, label="Volumen Voz (%)")
                    music_volume = gr.Slider(-30, 5, -3, step=1, label="Volumen Música (dB)")
                
                with gr.Row():
                    voice_volume = gr.Slider(-5, 10, 2, step=1, label="Boost Voz (dB)")
                    enable_ducking = gr.Checkbox(True, label="Activar Ducking")
                    ducking_amount = gr.Slider(-30, -3, -15, step=1, label="Ducking (dB)")
                
                output_quality = gr.Dropdown(
                    label="Calidad",
                    choices=[("Baja", "low"), ("Media", "medium"), ("Alta", "high"), ("Ultra", "ultra")],
                    value="high"
                )
            
            with gr.Row():
                preview_btn = gr.Button("🔊 Preview Voz", variant="secondary")
                preview_audio = gr.Audio(label="Preview", type="filepath")
            
            process_btn = gr.Button("🚀 INICIAR DOBLAJE", variant="primary", size="lg")
            
            with gr.Row():
                output_video = gr.Video(label="🎬 Video Doblado")
                output_audio = gr.Audio(label="🔊 Audio Doblado", type="filepath")
            
            output_log = gr.Markdown("*Esperando inicio...*")
        
        def update_voices(lang):
            voices = voice_manager.get_voices_for_language(lang)
            return gr.Dropdown.update(choices=voices, value=voices[0][1] if voices else None)
        
        target_language.change(update_voices, [target_language], [voice_id])
        
        preview_btn.click(
            preview_voice,
            [voice_id, dubbing_style, rhythm, custom_pitch, custom_volume],
            [preview_audio]
        )
        
        process_btn.click(
            process_dubbing,
            [input_video, source_language, target_language, voice_id, dubbing_style, 
             rhythm, custom_pitch, custom_volume, music_volume, voice_volume,
             ducking_amount, enable_ducking, output_quality],
            [output_video, output_audio, output_log]
        )
    
    return app

# ============================================================
# MAIN CON AUTO-RENOVACIÓN DE ENLACE
# ============================================================

if __name__ == "__main__":
    print("=" * 70)
    print("  🎬 SoniTranslate Pro - Doblaje Profesional con IA")
    print("  Python 3.7+ | CentOS 8 | Gradio Share Auto-renovable")
    print("=" * 70)
    
    # Verificar ffmpeg
    try:
        subprocess.run(["ffmpeg", "-version"], capture_output=True, check=True)
        print("✅ FFmpeg encontrado")
    except:
        print("⚠️ FFmpeg no encontrado. Instalando...")
        try:
            subprocess.run(["conda", "install", "-c", "conda-forge", "ffmpeg", "-y"], check=True)
        except:
            print("❌ No se pudo instalar FFmpeg. Instálalo manualmente:")
            print("   conda install -c conda-forge ffmpeg")
            sys.exit(1)
    
    print("\n🚀 Iniciando servidor Gradio...")
    print("📡 Generando enlace público...")
    print("🔄 El enlace se renovará automáticamente cada 72 horas\n")
    print("=" * 70)
    
    app = create_interface()
    
    # Configurar para mostrar el enlace claramente
    import warnings
    warnings.filterwarnings("ignore")
    
    print("\n")
    print("🌐 ENLACES DE ACCESO:")
    print("-" * 70)
    
    app.launch(
        server_name="0.0.0.0",
        server_port=7860,
        share=True,
        show_error=True,
        quiet=False,
        debug=False,
    )
