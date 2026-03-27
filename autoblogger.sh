#!/bin/bash

# ╔════════════════════════════════════════════════════════════════╗
# ║  AUTO NEWS BLOGGER PRO — CentOS 8 (sin root)                 ║
# ║  Blog: Yoelmod                                                ║
# ║  Motor IA: DeepSeek Chat (via OpenRouter)                     ║
# ║  Publicación: Blogger API v3                                   ║
# ║  Imágenes: Pexels (gratuitas)                                 ║
# ╚════════════════════════════════════════════════════════════════╝

set -e

SCRIPT_DIR="$HOME/autoblogger"
VENV_DIR="$SCRIPT_DIR/venv"
DATA_DIR="$SCRIPT_DIR/data"
PYTHON_SCRIPT="$SCRIPT_DIR/blogger_engine.py"

mkdir -p "$SCRIPT_DIR" "$DATA_DIR"

# ═══════════════════════════════════════════════════
# COLORES
# ═══════════════════════════════════════════════════
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${CYAN}  🚀 AUTO NEWS BLOGGER PRO — CentOS 8              ${NC}"
echo -e "${BOLD}${CYAN}  Blog: Yoelmod                                     ${NC}"
echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════${NC}"
echo ""

# ═══════════════════════════════════════════════════
# PASO 1: Verificar Python 3
# ═══════════════════════════════════════════════════
echo -e "${BLUE}📦 Verificando Python 3...${NC}"

PYTHON_CMD=""
for cmd in python3.9 python3.8 python3.7 python3.6 python3; do
    if command -v "$cmd" &>/dev/null; then
        PYTHON_CMD="$cmd"
        break
    fi
done

if [ -z "$PYTHON_CMD" ]; then
    echo -e "${RED}❌ Python 3 no encontrado${NC}"
    echo "   Pide al administrador que instale python3:"
    echo "   sudo dnf install python39 python39-pip"
    exit 1
fi

PY_VERSION=$($PYTHON_CMD --version 2>&1)
echo -e "${GREEN}   ✅ $PY_VERSION ($PYTHON_CMD)${NC}"

# ═══════════════════════════════════════════════════
# PASO 2: Crear entorno virtual
# ═══════════════════════════════════════════════════
if [ ! -d "$VENV_DIR" ]; then
    echo -e "${BLUE}📦 Creando entorno virtual...${NC}"
    $PYTHON_CMD -m venv "$VENV_DIR" 2>/dev/null || {
        echo -e "${YELLOW}   ⚠️ venv falló, intentando con --without-pip...${NC}"
        $PYTHON_CMD -m venv --without-pip "$VENV_DIR"
        source "$VENV_DIR/bin/activate"
        curl -sS https://bootstrap.pypa.io/get-pip.py | python
        deactivate
    }
    echo -e "${GREEN}   ✅ Entorno virtual creado${NC}"
else
    echo -e "${GREEN}   ✅ Entorno virtual existente${NC}"
fi

source "$VENV_DIR/bin/activate"

# ═══════════════════════════════════════════════════
# PASO 3: Instalar dependencias
# ═══════════════════════════════════════════════════
echo -e "${BLUE}📦 Instalando dependencias Python...${NC}"
pip install -q --upgrade pip 2>/dev/null
pip install -q \
    feedparser requests beautifulsoup4 lxml \
    google-auth google-auth-oauthlib google-auth-httplib2 \
    google-api-python-client openai 2>/dev/null
echo -e "${GREEN}   ✅ Dependencias instaladas${NC}"

# ═══════════════════════════════════════════════════
# PASO 4: Configuración interactiva
# ═══════════════════════════════════════════════════
echo ""
echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  CONFIGURACIÓN${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
echo ""

# --- Cargar config guardada si existe ---
CONFIG_FILE="$DATA_DIR/config.json"
if [ -f "$CONFIG_FILE" ]; then
    echo -e "${GREEN}   📂 Configuración guardada encontrada${NC}"
    echo -n "   ¿Usar configuración guardada? [s/n] (Enter=s): "
    read USE_SAVED
    if [ "$USE_SAVED" != "n" ] && [ "$USE_SAVED" != "no" ]; then
        echo -e "${GREEN}   ✅ Usando configuración guardada${NC}"
        SKIP_CONFIG="true"
    fi
fi

if [ "$SKIP_CONFIG" != "true" ]; then

    echo -e "${BOLD}🔑 API KEYS${NC}"
    echo "────────────────────────────────────"

    echo -n "   OpenRouter API Key: "
    read -s OPENROUTER_KEY
    echo ""
    while [ -z "$OPENROUTER_KEY" ]; do
        echo -e "   ${YELLOW}⚠️ Obligatorio${NC}"
        echo -n "   OpenRouter API Key: "
        read -s OPENROUTER_KEY
        echo ""
    done

    echo -n "   Pexels API Key: "
    read -s PEXELS_KEY
    echo ""
    while [ -z "$PEXELS_KEY" ]; do
        echo -e "   ${YELLOW}⚠️ Obligatorio${NC}"
        echo -n "   Pexels API Key: "
        read -s PEXELS_KEY
        echo ""
    done

    echo ""
    echo -e "${BOLD}📝 BLOGGER${NC}"
    echo "────────────────────────────────────"
    echo -n "   Blog ID: "
    read BLOG_ID
    while [ -z "$BLOG_ID" ]; do
        echo -e "   ${YELLOW}⚠️ Obligatorio${NC}"
        echo -n "   Blog ID: "
        read BLOG_ID
    done

    echo ""
    echo -e "${BOLD}🤖 MODELO DE IA${NC}"
    echo "────────────────────────────────────"
    echo "   1. deepseek/deepseek-chat        (muy barato)"
    echo "   2. openai/gpt-4o-mini            (buena calidad)"
    echo "   3. google/gemini-2.0-flash-001   (el mas barato)"
    echo "   4. anthropic/claude-sonnet-4     (premium)"
    echo "   5. Otro"
    echo -n "   Elige [1-5] (Enter=1): "
    read MODEL_CHOICE

    case "$MODEL_CHOICE" in
        2) MODEL_NAME="openai/gpt-4o-mini" ;;
        3) MODEL_NAME="google/gemini-2.0-flash-001" ;;
        4) MODEL_NAME="anthropic/claude-sonnet-4" ;;
        5)
            echo -n "   Nombre del modelo: "
            read MODEL_NAME
            ;;
        *) MODEL_NAME="deepseek/deepseek-chat" ;;
    esac

    echo ""
    echo -e "${BOLD}⚙️ COMPORTAMIENTO${NC}"
    echo "────────────────────────────────────"
    echo -n "   Posts por ejecución [1-20] (Enter=6): "
    read PPR
    [ -z "$PPR" ] && PPR=6

    echo -n "   Posts por categoría [1-5] (Enter=2): "
    read PPC
    [ -z "$PPC" ] && PPC=2

    echo -n "   Segundos entre posts (Enter=45): "
    read DELAY
    [ -z "$DELAY" ] && DELAY=45

    echo -n "   Publicar como borrador? [s/n] (Enter=s): "
    read DRAFT
    [ "$DRAFT" = "n" ] || [ "$DRAFT" = "no" ] && DRAFT="false" || DRAFT="true"

    echo ""
    echo -e "${BOLD}📰 CATEGORÍAS${NC}"
    echo "────────────────────────────────────"
    echo "   1.World News  2.Technology  3.Entertainment"
    echo "   4.Science     5.Business    6.TODAS"
    echo -n "   Elige (ej:1,2,3) Enter=todas: "
    read CATS
    [ -z "$CATS" ] && CATS="1,2,3,4,5"

    # Guardar configuración
    cat > "$CONFIG_FILE" << CONFIGEOF
{
    "openrouter_key": "$OPENROUTER_KEY",
    "pexels_key": "$PEXELS_KEY",
    "blog_id": "$BLOG_ID",
    "model": "$MODEL_NAME",
    "posts_per_run": $PPR,
    "posts_per_category": $PPC,
    "delay": $DELAY,
    "draft": $DRAFT,
    "categories": "$CATS"
}
CONFIGEOF
    chmod 600 "$CONFIG_FILE"
    echo -e "${GREEN}   💾 Configuración guardada${NC}"

fi

# ═══════════════════════════════════════════════════
# PASO 5: Verificar client_secret.json
# ═══════════════════════════════════════════════════
echo ""
echo -e "${BOLD}📤 CREDENCIALES BLOGGER${NC}"
echo "────────────────────────────────────"

CLIENT_SECRET="$DATA_DIR/client_secret.json"
if [ ! -f "$CLIENT_SECRET" ]; then
    echo -e "${YELLOW}   ⚠️ Falta client_secret.json${NC}"
    echo ""
    echo "   CÓMO OBTENERLO:"
    echo "   1. Ve a console.cloud.google.com"
    echo "   2. APIs → Biblioteca → Habilita 'Blogger API v3'"
    echo "   3. APIs → Credenciales"
    echo "   4. Crear → ID cliente OAuth 2.0"
    echo "   5. Tipo: 'App de escritorio' (Desktop)"
    echo "   6. Descargar JSON"
    echo "   7. Cópialo a: $CLIENT_SECRET"
    echo ""
    echo "   Puedes copiarlo con scp desde tu PC:"
    echo "   scp client_secret.json usuario@servidor:$CLIENT_SECRET"
    echo ""
    echo -n "   ¿Ya lo copiaste? [s/n]: "
    read COPIED
    if [ "$COPIED" != "s" ] && [ "$COPIED" != "si" ]; then
        echo -e "${RED}   ❌ Copia el archivo y vuelve a ejecutar${NC}"
        exit 1
    fi
    if [ ! -f "$CLIENT_SECRET" ]; then
        echo -e "${RED}   ❌ No encontrado en $CLIENT_SECRET${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}   ✅ client_secret.json encontrado${NC}"

# ═══════════════════════════════════════════════════
# PASO 6: Mostrar resumen
# ═══════════════════════════════════════════════════
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  RESUMEN${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════${NC}"

# Leer config
OPENROUTER_KEY=$(python3 -c "import json;print(json.load(open('$CONFIG_FILE'))['openrouter_key'])")
PEXELS_KEY=$(python3 -c "import json;print(json.load(open('$CONFIG_FILE'))['pexels_key'])")
BLOG_ID=$(python3 -c "import json;print(json.load(open('$CONFIG_FILE'))['blog_id'])")
MODEL_NAME=$(python3 -c "import json;print(json.load(open('$CONFIG_FILE'))['model'])")
PPR=$(python3 -c "import json;print(json.load(open('$CONFIG_FILE'))['posts_per_run'])")
PPC=$(python3 -c "import json;print(json.load(open('$CONFIG_FILE'))['posts_per_category'])")
DELAY=$(python3 -c "import json;print(json.load(open('$CONFIG_FILE'))['delay'])")
DRAFT=$(python3 -c "import json;print(json.load(open('$CONFIG_FILE'))['draft'])")
CATS=$(python3 -c "import json;print(json.load(open('$CONFIG_FILE'))['categories'])")

echo "   🔑 OpenRouter: ****${OPENROUTER_KEY: -6}"
echo "   🔑 Pexels:     ****${PEXELS_KEY: -6}"
echo "   📝 Blog ID:    $BLOG_ID"
echo "   🤖 Modelo:     $MODEL_NAME"
echo "   📰 Categorías: $CATS"
echo "   📊 Posts/run:   $PPR"
echo "   ⏳ Delay:       ${DELAY}s"
if [ "$DRAFT" = "true" ]; then
    echo "   📋 Modo:        BORRADOR"
else
    echo "   📋 Modo:        DIRECTO"
fi
echo -e "${CYAN}════════════════════════════════════════════════════${NC}"

echo ""
echo -n "   ¿Ejecutar? [s/n]: "
read CONFIRM
if [ "$CONFIRM" = "n" ] || [ "$CONFIRM" = "no" ]; then
    echo -e "${YELLOW}   Cancelado${NC}"
    exit 0
fi

# ═══════════════════════════════════════════════════
# PASO 7: Generar script Python
# ═══════════════════════════════════════════════════
echo ""
echo -e "${BLUE}🐍 Generando motor Python...${NC}"

cat > "$PYTHON_SCRIPT" << 'PYEOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# ╔════════════════════════════════════════════════════════════╗
# ║  AUTO NEWS BLOGGER PRO — Motor Python para CentOS 8       ║
# ║  Blog: Yoelmod                                            ║
# ╚════════════════════════════════════════════════════════════╝

import feedparser
import requests
from bs4 import BeautifulSoup
import random
import hashlib
import json
import os
import re
import sys
import time
from datetime import datetime, timezone
from urllib.parse import urlparse, parse_qs
from openai import OpenAI
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request as GReq
from googleapiclient.discovery import build

# ═══════════════════════════════════════
# CONFIGURACIÓN
# ═══════════════════════════════════════

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(SCRIPT_DIR, "data")
CONFIG_FILE = os.path.join(DATA_DIR, "config.json")
HISTORY_FILE = os.path.join(DATA_DIR, "posted_history.json")
TOKEN_FILE = os.path.join(DATA_DIR, "blogger_token.json")
CLIENT_SECRET = os.path.join(DATA_DIR, "client_secret.json")

BLOG_NAME = "Yoelmod"

with open(CONFIG_FILE, "r") as f:
    CFG = json.load(f)

OPENROUTER_API_KEY = CFG["openrouter_key"]
PEXELS_API_KEY = CFG["pexels_key"]
BLOGGER_BLOG_ID = CFG["blog_id"]
MODEL_NAME = CFG["model"]
POSTS_PER_RUN = int(CFG["posts_per_run"])
POSTS_PER_CATEGORY = int(CFG["posts_per_category"])
DELAY_BETWEEN = int(CFG["delay"])
PUBLISH_AS_DRAFT = CFG["draft"]
SELECTED_CATS = str(CFG["categories"]).split(",")

ALL_FEEDS = {
    "World News": [
        "http://feeds.bbci.co.uk/news/world/rss.xml",
        "https://rss.nytimes.com/services/xml/rss/nyt/World.xml",
        "https://feeds.npr.org/1004/rss.xml",
        "https://www.aljazeera.com/xml/rss/all.xml",
    ],
    "Technology": [
        "https://techcrunch.com/feed/",
        "https://www.theverge.com/rss/index.xml",
        "http://feeds.arstechnica.com/arstechnica/index",
        "https://www.wired.com/feed/rss",
    ],
    "Entertainment": [
        "http://feeds.bbci.co.uk/news/entertainment_and_arts/rss.xml",
        "https://deadline.com/feed/",
        "https://variety.com/feed/",
    ],
    "Science": [
        "http://feeds.bbci.co.uk/news/science_and_environment/rss.xml",
        "https://rss.nytimes.com/services/xml/rss/nyt/Science.xml",
    ],
    "Business": [
        "http://feeds.bbci.co.uk/news/business/rss.xml",
        "https://rss.nytimes.com/services/xml/rss/nyt/Business.xml",
    ],
}

C_MAP = {"1": "World News", "2": "Technology",
         "3": "Entertainment", "4": "Science", "5": "Business"}
RSS_FEEDS = {}
for n in SELECTED_CATS:
    n = n.strip()
    cn = C_MAP.get(n)
    if cn and cn in ALL_FEEDS:
        RSS_FEEDS[cn] = ALL_FEEDS[cn]
if not RSS_FEEDS:
    RSS_FEEDS = ALL_FEEDS.copy()


# ═══════════════════════════════════════
# UTILIDADES
# ═══════════════════════════════════════

def now_utc():
    return datetime.now(timezone.utc)

def now_str():
    return now_utc().strftime("%Y-%m-%d %H:%M UTC")

def now_date():
    return now_utc().strftime("%B %d, %Y")

def log(msg):
    print(msg, flush=True)


# ═══════════════════════════════════════
# SCRAPER
# ═══════════════════════════════════════

class NewsScraper:

    def __init__(self):
        self.ua = (
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
            "AppleWebKit/537.36 Chrome/125.0.0.0 Safari/537.36"
        )
        self.history = self._load()

    def _load(self):
        if os.path.exists(HISTORY_FILE):
            with open(HISTORY_FILE, "r") as f:
                return set(json.load(f))
        return set()

    def _save(self):
        with open(HISTORY_FILE, "w") as f:
            json.dump(list(self.history), f)

    def _hsh(self, t):
        return hashlib.md5(t.lower().strip().encode()).hexdigest()

    def _strip(self, txt):
        if not txt:
            return ""
        return BeautifulSoup(txt, "html.parser").get_text().strip()

    def _full_text(self, url):
        try:
            r = requests.get(
                url, headers={"User-Agent": self.ua}, timeout=15
            )
            r.raise_for_status()
            soup = BeautifulSoup(r.text, "lxml")
            for t in soup.find_all(
                ["script", "style", "nav", "footer",
                 "header", "aside", "iframe"]
            ):
                t.decompose()
            body = soup.find("article")
            if not body:
                body = soup.find(
                    "div",
                    class_=lambda x: x and any(
                        k in str(x).lower()
                        for k in ["article", "content", "story", "post-body"]
                    )
                )
            if not body:
                body = soup.body
            parrs = body.find_all("p") if body else []
            skip = [
                "cookie", "subscribe", "newsletter",
                "advertisement", "copyright", "read more",
                "click here", "terms of", "sign up",
                "all rights reserved"
            ]
            parts = []
            for p in parrs:
                tx = p.get_text().strip()
                if len(tx) > 40:
                    if not any(s in tx.lower() for s in skip):
                        parts.append(tx)
            return " ".join(parts[:25])[:5000]
        except Exception:
            return ""

    def mark(self, h):
        self.history.add(h)
        self._save()

    def fetch(self):
        everything = []
        for cat, feeds in RSS_FEEDS.items():
            log("  📡 " + cat + "...")
            bucket = []
            for furl in feeds:
                try:
                    fd = feedparser.parse(furl)
                    src = fd.feed.get("title", furl.split("/")[2])
                    for entry in fd.entries[:8]:
                        title = entry.get("title", "").strip()
                        if not title:
                            continue
                        h = self._hsh(title)
                        if h in self.history:
                            continue
                        link = entry.get("link", "")
                        summ = self._strip(entry.get("summary", ""))[:500]
                        full = self._full_text(link)
                        bucket.append({
                            "title": title, "link": link,
                            "summary": summ, "full_content": full,
                            "source_name": src, "source_url": link,
                            "category": cat, "hash": h,
                        })
                except Exception as e:
                    log("     ⚠️ " + str(e)[:60])
            random.shuffle(bucket)
            sel = bucket[:POSTS_PER_CATEGORY]
            everything.extend(sel)
            log("     ✅ " + str(len(sel)) + " noticias")
        return everything


# ═══════════════════════════════════════
# GENERADOR IA — EDITOR PROFESIONAL
# ═══════════════════════════════════════

class ContentGenerator:

    def __init__(self):
        self.client = OpenAI(
            base_url="https://openrouter.ai/api/v1",
            api_key=OPENROUTER_API_KEY,
        )
        self.personas = [
            "Senior Digital Editor at The Economist. "
            "20 years experience. Elegant prose, sharp analysis.",
            "Chief Content Strategist at Vox. Transforms "
            "raw news into immersive reading experiences.",
            "Executive Editor at BBC Future. Authoritative "
            "yet approachable. Finds the human story.",
            "Editorial Director at Reuters. Wire-service "
            "precision with magazine-quality polish.",
            "Lead Features Editor at Wired. Intelligent "
            "without pretension, detailed without tedium.",
        ]

    def generate(self, news):
        persona = random.choice(self.personas)
        src_block = (
            "=== SOURCE ===\n"
            "Publication: " + news["source_name"] + "\n"
            "URL: " + news["source_url"] + "\n"
            "Headline: " + news["title"] + "\n"
            "Category: " + news["category"] + "\n"
            "Summary: " + news["summary"] + "\n"
            "Full Text:\n"
            + (news["full_content"][:3500]
               if news["full_content"]
               else "[Limited — use summary.]")
            + "\n=== END ===\n"
        )
        sys_msg = (
            "You are a " + persona + "\n\n"
            "RULES:\n"
            "1. ONLY facts from source. NEVER fabricate.\n"
            "2. Preserve numbers, dates, names exactly.\n"
            "3. NEVER copy verbatim. Rewrite completely.\n"
            "4. Vary sentence lengths naturally.\n"
            "5. Cite source naturally in text.\n"
            "6. Powerful lede, inverted pyramid.\n"
            "7. Active voice 80%, passive 20%.\n"
            "8. Include quotes if in source.\n"
            "9. End with implications.\n"
            "10. Use contractions naturally.\n"
            "11. HTML: <p> <h2> <strong> <blockquote> <em>\n"
            "12. No inline styles in article_body.\n\n"
            "BANNED: 'In conclusion', 'worth noting', "
            "'remains to be seen', 'time will tell', "
            "'ever-evolving', 'dive into', 'delve into', "
            "'game-changer', 'paradigm shift', "
            "'end of the day', 'first and foremost', "
            "'without further ado', 'in this article', "
            "'buckle up', 'navigate', 'realm of', "
            "'tapestry', 'testament to', 'shockwaves', "
            "'raises questions', 'growing concern', "
            "'underscores', 'sparking debate'.\n\n"
            "NEVER mention AI. English ONLY.\n"
        )
        usr_msg = (
            "Craft a polished article:\n\n"
            + src_block + "\n"
            "RAW JSON ONLY:\n"
            '{"headline":"8-14 word magnetic headline",'
            '"subheadline":"15-25 word deck",'
            '"meta_description":"150-160 char SEO",'
            '"article_body":"HTML. Lede + 2-3 h2 sections '
            '+ closing. 700-1000 words. FACTS FROM SOURCE",'
            '"pull_quote":"Most compelling sentence",'
            '"tags":["t1","t2","t3","t4","t5"],'
            '"image_search_query":"2-4 words Pexels",'
            '"reading_time":"X min read"}'
        )
        try:
            resp = self.client.chat.completions.create(
                model=MODEL_NAME,
                messages=[
                    {"role": "system", "content": sys_msg},
                    {"role": "user", "content": usr_msg}
                ],
                temperature=0.82, top_p=0.88,
                max_tokens=3500,
                frequency_penalty=0.35,
                presence_penalty=0.25,
            )
            raw = resp.choices[0].message.content.strip()
            return self._parse(raw, news)
        except Exception as e:
            log("     ❌ IA: " + str(e))
            return None

    def _parse(self, raw, news):
        try:
            c = raw
            if c.startswith("```"):
                c = re.sub(r'^```(?:json)?\s*', '', c)
                c = re.sub(r'\s*```\s*$', '', c)
            data = json.loads(c)
            data["source_name"] = news["source_name"]
            data["source_url"] = news["source_url"]
            data["category"] = news["category"]
            data["hash"] = news["hash"]
            return data
        except json.JSONDecodeError:
            return self._rescue(raw, news)

    def _rescue(self, text, news):
        try:
            def grab(pat, d=""):
                m = re.search(pat, text, re.DOTALL)
                return m.group(1).strip() if m else d
            hl = grab(r'"headline"\s*:\s*"((?:[^"\\]|\\.)*)"', news["title"])
            bd = grab(r'"article_body"\s*:\s*"((?:[^"\\]|\\.)*)"', "")
            if not bd:
                bd = "<p>Error. Retry.</p>"
            bd = bd.replace("\\n", "\n").replace('\\"', '"')
            sub = grab(r'"subheadline"\s*:\s*"((?:[^"\\]|\\.)*)"', "")
            mt = grab(r'"meta_description"\s*:\s*"((?:[^"\\]|\\.)*)"', "")
            iq = grab(r'"image_search_query"\s*:\s*"((?:[^"\\]|\\.)*)"', news["category"])
            pq = grab(r'"pull_quote"\s*:\s*"((?:[^"\\]|\\.)*)"', "")
            rt = grab(r'"reading_time"\s*:\s*"((?:[^"\\]|\\.)*)"', "4 min read")
            tm = re.search(r'"tags"\s*:\s*\[(.*?)\]', text)
            tgs = ([t.strip().strip('"').strip("'")
                    for t in tm.group(1).split(",")]
                   if tm else [news["category"]])
            return {
                "headline": hl, "subheadline": sub,
                "article_body": bd, "meta_description": mt,
                "tags": tgs, "image_search_query": iq,
                "pull_quote": pq, "reading_time": rt,
                "source_name": news["source_name"],
                "source_url": news["source_url"],
                "category": news["category"],
                "hash": news["hash"],
            }
        except Exception:
            return None

    def check(self, body):
        bad = [
            r"worth noting", r"in conclusion",
            r"remains to be seen", r"time will tell",
            r"ever.evolving", r"dive into", r"delve into",
            r"game.changer", r"paradigm shift",
            r"end of the day", r"first and foremost",
            r"buckle up", r"the realm of", r"tapestry of",
            r"testament to", r"important to note",
            r"shockwaves", r"raises questions",
            r"growing concern", r"sparking debate",
        ]
        return [p for p in bad if re.search(p, body, re.IGNORECASE)]


# ═══════════════════════════════════════
# IMÁGENES PEXELS
# ═══════════════════════════════════════

class ImageHandler:

    def __init__(self):
        self.hdr = {"Authorization": PEXELS_API_KEY}

    def find(self, query):
        try:
            r = requests.get(
                "https://api.pexels.com/v1/search",
                headers=self.hdr,
                params={"query": query, "orientation": "landscape",
                        "size": "large", "per_page": 10},
                timeout=10
            )
            r.raise_for_status()
            photos = r.json().get("photos", [])
            if photos:
                p = random.choice(photos[:5])
                return {
                    "url": p["src"]["large2x"],
                    "alt": p.get("alt", query),
                    "photographer": p["photographer"],
                    "photographer_url": p["photographer_url"],
                    "pexels_url": p["url"],
                }
            simple = " ".join(query.split()[:2])
            if simple != query:
                return self.find(simple)
            return self._fb()
        except Exception:
            return self._fb()

    def _fb(self):
        return {
            "url": "https://images.pexels.com/photos/518543/pexels-photo-518543.jpeg",
            "alt": "News", "photographer": "Pexels",
            "photographer_url": "https://pexels.com",
            "pexels_url": "https://pexels.com",
        }


# ═══════════════════════════════════════
# FORMATEADOR HTML PROFESIONAL
# ═══════════════════════════════════════

class HTMLFormatter:

    CAT_STYLES = {
        "World News": {"color": "#C0392B", "icon": "&#127758;", "gradient": "#e74c3c,#c0392b"},
        "Technology": {"color": "#2471A3", "icon": "&#128187;", "gradient": "#3498db,#2471a3"},
        "Entertainment": {"color": "#8E44AD", "icon": "&#127916;", "gradient": "#9b59b6,#8e44ad"},
        "Science": {"color": "#27AE60", "icon": "&#128300;", "gradient": "#2ecc71,#27ae60"},
        "Business": {"color": "#D35400", "icon": "&#128202;", "gradient": "#e67e22,#d35400"},
    }

    def format(self, article, image):
        ds = now_date()
        cat = article.get("category", "News")
        cs = self.CAT_STYLES.get(cat, {"color": "#2C3E50", "icon": "&#128240;", "gradient": "#34495e,#2c3e50"})
        clr = cs["color"]
        icn = cs["icon"]
        grd = cs["gradient"]
        phot = image.get("photographer", "Pexels")
        phot_url = image.get("photographer_url", "https://pexels.com")
        pex_url = image.get("pexels_url", "https://pexels.com")

        if phot != "Pexels":
            credit = (
                '<p style="text-align:center;font-size:11px;color:#aaa;'
                'margin:8px 0 0 0;font-family:Arial,sans-serif;">'
                'Photo by <a href="' + phot_url
                + '" target="_blank" rel="noopener" style="color:#aaa;'
                'text-decoration:underline;">' + phot + '</a> — '
                '<a href="' + pex_url
                + '" target="_blank" rel="noopener" style="color:#aaa;'
                'text-decoration:underline;">Pexels</a></p>'
            )
        else:
            credit = ""

        subhl = article.get("subheadline", "")
        subhl_html = ""
        if subhl:
            subhl_html = (
                '<p style="font-size:19px;color:#555;font-family:Georgia,serif;'
                'line-height:1.6;margin:0 0 25px 0;font-style:italic;'
                'border-left:3px solid ' + clr + ';padding-left:18px;">'
                + subhl + '</p>'
            )

        pq = article.get("pull_quote", "")
        pq_html = ""
        if pq:
            pq_html = (
                '<div style="margin:35px 0;padding:30px 35px;position:relative;'
                'background:linear-gradient(135deg,#f8f9fa,#fff);border-radius:8px;">'
                '<div style="position:absolute;top:-15px;left:25px;font-size:60px;'
                'color:' + clr + ';opacity:0.3;font-family:Georgia,serif;'
                'line-height:1;">&ldquo;</div>'
                '<p style="font-size:22px;font-family:Georgia,serif;'
                'font-style:italic;color:#2c2c2c;line-height:1.5;margin:0;'
                'position:relative;z-index:1;padding-top:10px;">'
                + pq + '</p>'
                '<div style="width:60px;height:3px;background:' + clr + ';'
                'margin:18px 0 0 0;border-radius:2px;"></div></div>'
            )

        rt = article.get("reading_time", "4 min read")
        tgs_html = ""
        for tg in article.get("tags", [])[:5]:
            tgs_html += (
                '<a style="display:inline-block;background:#f0f2f5;color:#555;'
                'padding:6px 16px;border-radius:25px;font-size:12px;margin:4px 5px;'
                'font-weight:500;text-decoration:none;font-family:Arial,sans-serif;'
                'border:1px solid #e0e0e0;">#' + str(tg) + '</a>'
            )

        sn = article.get("source_name", "Source")
        su = article.get("source_url", "#")
        bd = article.get("article_body", "")
        iu = image.get("url", "")
        ia = image.get("alt", "")

        html = (
            '<div style="max-width:800px;margin:0 auto;font-family:Georgia,serif;'
            'color:#2c2c2c;background:#fff;">'
            '<div style="margin:0 0 30px 0;border-radius:12px;overflow:hidden;'
            'box-shadow:0 4px 20px rgba(0,0,0,0.1);">'
            '<img src="' + iu + '" alt="' + ia + '" '
            'style="width:100%;height:auto;display:block;" loading="lazy" />'
            '</div>' + credit
            + '<div style="display:flex;align-items:center;flex-wrap:wrap;'
            'gap:12px;margin:20px 0 15px 0;font-family:Arial,sans-serif;">'
            '<span style="background:linear-gradient(135deg,' + grd + ');'
            'color:#fff;padding:5px 16px;border-radius:25px;font-weight:700;'
            'text-transform:uppercase;font-size:11px;letter-spacing:1.5px;'
            'display:inline-flex;align-items:center;gap:5px;">'
            + icn + ' ' + cat + '</span>'
            '<span style="color:#999;font-size:13px;">' + ds + '</span>'
            '<span style="color:#ddd;">|</span>'
            '<span style="color:#999;font-size:13px;">' + rt + '</span>'
            '</div>'
            '<div style="height:3px;background:linear-gradient(90deg,'
            + clr + ',transparent);border-radius:2px;margin:0 0 25px 0;"></div>'
            + subhl_html
            + '<div style="font-size:18px;line-height:1.95;color:#333;">'
            '<style>.ab h2{font-family:Arial,Helvetica,sans-serif;font-size:24px;'
            'font-weight:700;color:#1a1a1a;margin:35px 0 15px 0;padding-bottom:8px;'
            'border-bottom:2px solid ' + clr + ';line-height:1.3;}'
            '.ab p{margin:0 0 18px 0;}.ab blockquote{margin:25px 0;padding:20px 25px;'
            'border-left:4px solid ' + clr + ';background:#fafafa;font-style:italic;'
            'color:#444;border-radius:0 8px 8px 0;font-size:17px;line-height:1.7;}'
            '.ab strong{color:#1a1a1a;font-weight:700;}.ab em{color:#555;}'
            '.ab ul,.ab ol{margin:15px 0;padding-left:25px;}'
            '.ab li{margin:8px 0;line-height:1.7;}</style>'
            '<div class="ab">' + bd + '</div></div>'
            + pq_html
            + '<div style="text-align:center;margin:40px 0;color:#ddd;'
            'font-size:20px;letter-spacing:8px;">&bull; &bull; &bull;</div>'
            '<div style="background:linear-gradient(135deg,#f8f9fa,#f0f2f5);'
            'border-radius:10px;padding:22px 28px;margin:25px 0;'
            'font-family:Arial,sans-serif;font-size:14px;border:1px solid #e8e8e8;">'
            '<div style="display:flex;align-items:center;gap:10px;margin-bottom:8px;">'
            '<span style="font-size:20px;">&#128240;</span>'
            '<strong style="font-size:14px;color:#333;">Original Source</strong></div>'
            '<a href="' + su + '" target="_blank" rel="noopener nofollow" '
            'style="color:' + clr + ';text-decoration:none;font-weight:600;'
            'font-size:15px;">' + sn + ' &rarr;</a>'
            '<p style="color:#999;font-size:12px;margin:10px 0 0 0;line-height:1.5;">'
            'Independently written and edited based on verified reports.</p></div>'
            '<div style="margin:25px 0 10px 0;padding-top:20px;border-top:1px solid #eee;">'
            '<p style="font-family:Arial,sans-serif;font-size:11px;text-transform:uppercase;'
            'letter-spacing:1.5px;color:#aaa;margin:0 0 10px 0;font-weight:600;">'
            'Related Topics</p>' + tgs_html + '</div>'
            '<div style="margin-top:30px;padding:20px 0;border-top:2px solid #f0f0f0;'
            'text-align:center;font-family:Arial,sans-serif;">'
            '<p style="font-size:12px;color:#bbb;margin:0;">'
            + BLOG_NAME + ' &mdash; Trusted News, Global Reach</p></div>'
            '</div>'
        )
        return html


# ═══════════════════════════════════════
# PUBLICADOR BLOGGER — OAuth Manual
# ═══════════════════════════════════════

class BloggerPublisher:

    SCOPES = ["https://www.googleapis.com/auth/blogger"]

    def __init__(self):
        self.blog_id = BLOGGER_BLOG_ID
        self.service = None

    def authenticate(self):
        creds = None

        # Token guardado
        if os.path.exists(TOKEN_FILE):
            try:
                creds = Credentials.from_authorized_user_file(
                    TOKEN_FILE, self.SCOPES
                )
                if creds and creds.valid:
                    self.service = build("blogger", "v3", credentials=creds)
                    blog = self.service.blogs().get(blogId=self.blog_id).execute()
                    log("  ✅ Token válido — Blog: " + blog["name"])
                    log("  🔗 " + blog["url"])
                    return True
                elif creds and creds.expired and creds.refresh_token:
                    log("  🔄 Renovando token...")
                    creds.refresh(GReq())
                    with open(TOKEN_FILE, "w") as f:
                        f.write(creds.to_json())
                    self.service = build("blogger", "v3", credentials=creds)
                    blog = self.service.blogs().get(blogId=self.blog_id).execute()
                    log("  ✅ Renovado — Blog: " + blog["name"])
                    return True
            except Exception as e:
                log("  ⚠️ Token guardado inválido: " + str(e)[:60])
                creds = None

        # OAuth Manual
        if not os.path.exists(CLIENT_SECRET):
            log("  ❌ Falta " + CLIENT_SECRET)
            return False

        with open(CLIENT_SECRET, "r") as f:
            cc = json.load(f)

        if "installed" in cc:
            cfg = cc["installed"]
        elif "web" in cc:
            cfg = cc["web"]
        else:
            log("  ❌ Formato no reconocido")
            return False

        cid = cfg["client_id"]
        csec = cfg["client_secret"]
        turi = cfg.get("token_uri", "https://oauth2.googleapis.com/token")

        # Detectar tipo y elegir redirect_uri
        if "web" in cc:
            ruri = "http://localhost:8085"
            log("")
            log("  ⚠️ Cliente tipo 'Web Application' detectado")
            log("  Asegúrate de haber agregado esta URI")
            log("  en Google Cloud Console:")
            log("  http://localhost:8085")
            log("")
        else:
            ruri = "http://localhost:8085"

        scp = " ".join(self.SCOPES)
        aurl = (
            "https://accounts.google.com/o/oauth2/v2/auth"
            "?client_id=" + cid
            + "&redirect_uri=" + ruri
            + "&response_type=code"
            + "&scope=" + scp
            + "&access_type=offline"
            + "&prompt=consent"
        )

        log("")
        log("  🔐 AUTENTICACIÓN OAUTH2")
        log("  " + "=" * 50)
        log("")
        log("  1. Abre este enlace en tu navegador:")
        log("")
        log("  " + aurl)
        log("")
        log("  2. Inicia sesión y autoriza")
        log("  3. La página NO CARGARÁ (normal)")
        log("  4. Copia la URL COMPLETA de la barra")
        log("     Ejemplo: http://localhost:8085/?code=4/0Axx...")
        log("")

        user_input = input("  5. Pega la URL aquí: ").strip()

        if not user_input:
            log("  ❌ Vacío")
            return False

        auth_code = None
        if "code=" in user_input:
            try:
                parsed = urlparse(user_input)
                params = parse_qs(parsed.query)
                if "code" in params:
                    auth_code = params["code"][0]
            except Exception:
                pass
            if not auth_code:
                m = re.search(r'code=([^&\s]+)', user_input)
                if m:
                    auth_code = m.group(1)
        if not auth_code:
            auth_code = user_input.strip()

        log("  ✅ Código: " + auth_code[:20] + "...")
        log("  🔄 Obteniendo token...")

        try:
            tr = requests.post(
                turi,
                data={
                    "code": auth_code,
                    "client_id": cid,
                    "client_secret": csec,
                    "redirect_uri": ruri,
                    "grant_type": "authorization_code",
                },
                timeout=30
            )
            td = tr.json()

            if "error" in td:
                log("  ❌ " + td.get("error_description", td["error"]))
                return False

            creds = Credentials(
                token=td["access_token"],
                refresh_token=td.get("refresh_token"),
                token_uri=turi,
                client_id=cid,
                client_secret=csec,
                scopes=self.SCOPES,
            )

            ts = {
                "token": td["access_token"],
                "refresh_token": td.get("refresh_token"),
                "token_uri": turi,
                "client_id": cid,
                "client_secret": csec,
                "scopes": self.SCOPES,
            }
            with open(TOKEN_FILE, "w") as f:
                json.dump(ts, f)
            os.chmod(TOKEN_FILE, 0o600)

            log("  ✅ Token guardado")

            self.service = build("blogger", "v3", credentials=creds)
            blog = self.service.blogs().get(blogId=self.blog_id).execute()
            log("  ✅ Blog: " + blog["name"])
            log("  🔗 " + blog["url"])
            tp = blog.get("posts", {}).get("totalItems", 0)
            log("  📝 Posts: " + str(tp))
            return True

        except Exception as e:
            log("  ❌ Error: " + str(e))
            return False

    def publish(self, title, html, labels=None, draft=True):
        if not self.service:
            return None
        post = {
            "kind": "blogger#post",
            "blog": {"id": self.blog_id},
            "title": title,
            "content": html,
        }
        if labels:
            post["labels"] = labels
        try:
            r = self.service.posts().insert(
                blogId=self.blog_id, body=post, isDraft=draft
            ).execute()
            if draft:
                log("     📝 BORRADOR: " + title[:50] + "...")
            else:
                log("     ✅ PUBLICADO: " + title[:50] + "...")
            url = r.get("url", "")
            if url:
                log("     🔗 " + url)
            return r
        except Exception as e:
            log("     ❌ " + str(e))
            return None


# ═══════════════════════════════════════
# PIPELINE PRINCIPAL
# ═══════════════════════════════════════

def run():
    log("")
    log("=" * 60)
    log("  🚀 YOELMOD AUTO BLOGGER — PIPELINE")
    log("  " + now_str())
    log("  Modelo: " + MODEL_NAME)
    modo = "BORRADOR" if PUBLISH_AS_DRAFT else "DIRECTO"
    log("  Modo: " + modo)
    log("=" * 60)

    scraper = NewsScraper()
    gen = ContentGenerator()
    img = ImageHandler()
    fmt = HTMLFormatter()
    pub = BloggerPublisher()

    log("\n🔐 Autenticando...")
    if not pub.authenticate():
        log("❌ Fallo autenticación")
        return

    log("\n📡 Buscando noticias...")
    news_list = scraper.fetch()
    if not news_list:
        log("❌ Sin noticias")
        return

    to_do = news_list[:POSTS_PER_RUN]
    total = len(to_do)
    log("\n📝 " + str(total) + " artículos\n")

    ok_n = 0
    fail_n = 0

    for i, news in enumerate(to_do):
        num = str(i + 1) + "/" + str(total)
        log("-" * 55)
        log("📰 [" + num + "] " + news["title"][:55] + "...")
        log("   Fuente: " + news["source_name"])
        log("   Cat: " + news["category"])

        log("   🤖 Generando...")
        article = gen.generate(news)
        if not article:
            fail_n += 1
            continue

        warns = gen.check(article.get("article_body", ""))
        if warns:
            log("   ⚠️ " + ", ".join(warns[:3]))

        log("   ✅ " + article["headline"][:50] + "...")

        log("   🖼️ Imagen...")
        q = article.get("image_search_query", news["category"])
        image = img.find(q)
        log("   ✅ " + image["photographer"])

        log("   🎨 Diseñando...")
        html = fmt.format(article, image)

        log("   📤 Publicando...")
        labels = list(set(
            [news["category"]] + article.get("tags", [])[:3]
        ))
        result = pub.publish(
            title=article["headline"], html=html,
            labels=labels, draft=PUBLISH_AS_DRAFT,
        )

        if result:
            ok_n += 1
            scraper.mark(news["hash"])
        else:
            fail_n += 1

        if i < total - 1:
            wait = random.uniform(DELAY_BETWEEN, DELAY_BETWEEN * 1.8)
            log("   ⏳ " + str(int(wait)) + "s...")
            time.sleep(wait)

    log("")
    log("=" * 60)
    log("  📊 RESUMEN")
    log("=" * 60)
    log("  ✅ Exitosos: " + str(ok_n))
    log("  ❌ Fallidos: " + str(fail_n))
    log("  Modo: " + modo)
    log("=" * 60)
    log("  ✅ COMPLETADO — " + now_str())
    log("=" * 60)


if __name__ == "__main__":
    run()
PYEOF

echo -e "${GREEN}   ✅ Motor generado${NC}"

# ═══════════════════════════════════════════════════
# PASO 8: Ejecutar
# ═══════════════════════════════════════════════════
echo ""
echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  🚀 EJECUTANDO PIPELINE                              ${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
echo ""

python "$PYTHON_SCRIPT"
EXIT_CODE=$?

deactivate 2>/dev/null

# ═══════════════════════════════════════════════════
# PASO 9: Ofrecer cron job
# ═══════════════════════════════════════════════════
if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}  ⏰ AUTOMATIZACIÓN CON CRON${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
    echo ""
    echo "  ¿Quieres programar ejecución automática?"
    echo ""
    echo "  1. Cada 6 horas"
    echo "  2. Cada 12 horas"
    echo "  3. Una vez al día (9:00 AM)"
    echo "  4. Dos veces al día (9:00 AM y 6:00 PM)"
    echo "  5. No, solo manual"
    echo ""
    echo -n "  Elige [1-5] (Enter=5): "
    read CRON_CHOICE

    # Crear script de ejecución silenciosa
    RUNNER="$SCRIPT_DIR/run_silent.sh"
    cat > "$RUNNER" << RUNEOF
#!/bin/bash
cd $SCRIPT_DIR
source $VENV_DIR/bin/activate
python $PYTHON_SCRIPT >> $DATA_DIR/cron.log 2>&1
deactivate
RUNEOF
    chmod +x "$RUNNER"

    CRON_LINE=""
    case "$CRON_CHOICE" in
        1)
            CRON_LINE="0 */6 * * * $RUNNER"
            echo -e "${GREEN}   ✅ Cada 6 horas${NC}"
            ;;
        2)
            CRON_LINE="0 */12 * * * $RUNNER"
            echo -e "${GREEN}   ✅ Cada 12 horas${NC}"
            ;;
        3)
            CRON_LINE="0 9 * * * $RUNNER"
            echo -e "${GREEN}   ✅ Diario a las 9:00 AM${NC}"
            ;;
        4)
            CRON_LINE="0 9,18 * * * $RUNNER"
            echo -e "${GREEN}   ✅ 9:00 AM y 6:00 PM${NC}"
            ;;
        *)
            echo -e "${YELLOW}   ℹ️ Solo manual${NC}"
            ;;
    esac

    if [ -n "$CRON_LINE" ]; then
        # Remover cron anterior si existe
        crontab -l 2>/dev/null | grep -v "$RUNNER" | crontab - 2>/dev/null
        # Agregar nuevo
        (crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab -
        echo ""
        echo -e "${GREEN}   ✅ Cron configurado${NC}"
        echo "   Para ver: crontab -l"
        echo "   Para quitar: crontab -e (borrar la línea)"
        echo "   Logs en: $DATA_DIR/cron.log"
    fi
fi

echo ""
echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  COMANDOS ÚTILES${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
echo ""
echo "  Ejecutar manualmente:"
echo "    $SCRIPT_DIR/autoblogger.sh"
echo ""
echo "  Ver logs del cron:"
echo "    tail -f $DATA_DIR/cron.log"
echo ""
echo "  Ver historial de posts:"
echo "    cat $DATA_DIR/posted_history.json | python3 -m json.tool"
echo ""
echo "  Borrar historial (re-publicar todo):"
echo "    rm $DATA_DIR/posted_history.json"
echo ""
echo "  Reconfigurar:"
echo "    rm $DATA_DIR/config.json && $SCRIPT_DIR/autoblogger.sh"
echo ""
echo "  Ver/quitar cron:"
echo "    crontab -l"
echo "    crontab -r   (quita TODO)"
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}  ✅ YOELMOD AUTO BLOGGER — FIN${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
