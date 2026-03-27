mkdir -p ~/autoblogger/data && cat > ~/autoblogger/autoblogger.sh << 'MAINEOF'
#!/bin/bash

# ╔════════════════════════════════════════════════════════════════╗
# ║  YOELMOD AUTO NEWS BLOGGER — CentOS 8 Terminal Puro           ║
# ║  client_secret.json se pega directo en terminal               ║
# ║  Scheduling flexible: elige cantidad y frecuencia             ║
# ╚════════════════════════════════════════════════════════════════╝

set -e

DIR="$HOME/autoblogger"
VENV="$DIR/venv"
DATA="$DIR/data"
ENGINE="$DIR/engine.py"
RUNNER="$DIR/run_auto.sh"
CONFIG="$DATA/config.json"
CLIENT="$DATA/client_secret.json"
TOKEN="$DATA/blogger_token.json"
HISTORY="$DATA/posted_history.json"
LOGFILE="$DATA/autoblogger.log"

mkdir -p "$DATA"

R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
B='\033[0;34m'
C='\033[0;36m'
W='\033[1m'
N='\033[0m'

clear
echo ""
echo -e "${W}${C}══════════════════════════════════════════════════${N}"
echo -e "${W}${C}  🚀 YOELMOD AUTO NEWS BLOGGER                    ${N}"
echo -e "${W}${C}  CentOS 8 — Terminal Puro                        ${N}"
echo -e "${W}${C}══════════════════════════════════════════════════${N}"
echo ""

# ═══════════════════════════════════════
# PYTHON
# ═══════════════════════════════════════
echo -e "${B}📦 Verificando Python...${N}"
PY=""
for cmd in python3.11 python3.10 python3.9 python3.8 python3; do
    if command -v "$cmd" &>/dev/null; then
        PY="$cmd"
        break
    fi
done
if [ -z "$PY" ]; then
    echo -e "${R}❌ Python 3 no encontrado${N}"
    echo "   Pide: sudo dnf install python39 python39-pip"
    exit 1
fi
echo -e "${G}   ✅ $($PY --version) ($PY)${N}"

# ═══════════════════════════════════════
# VENV
# ═══════════════════════════════════════
if [ ! -d "$VENV" ]; then
    echo -e "${B}📦 Creando entorno virtual...${N}"
    $PY -m venv "$VENV" 2>/dev/null || {
        $PY -m venv --without-pip "$VENV"
        source "$VENV/bin/activate"
        curl -sS https://bootstrap.pypa.io/get-pip.py | python
        deactivate
    }
    echo -e "${G}   ✅ Creado${N}"
fi
source "$VENV/bin/activate"

echo -e "${B}📦 Dependencias...${N}"
pip install -q --upgrade pip 2>/dev/null
pip install -q feedparser requests beautifulsoup4 lxml \
    google-auth google-auth-oauthlib google-auth-httplib2 \
    google-api-python-client openai 2>/dev/null
echo -e "${G}   ✅ Listas${N}"

# ═══════════════════════════════════════
# CLIENT SECRET — PEGAR EN TERMINAL
# ═══════════════════════════════════════
echo ""
echo -e "${W}${C}══════════════════════════════════════════════════${N}"
echo -e "${W}  📤 CREDENCIALES GOOGLE (client_secret.json)${N}"
echo -e "${C}══════════════════════════════════════════════════${N}"

if [ -f "$CLIENT" ]; then
    echo -e "${G}   ✅ client_secret.json ya existe${N}"
    echo -n "   ¿Reemplazar? [s/n] (Enter=n): "
    read REPLACE_CS
    if [ "$REPLACE_CS" != "s" ] && [ "$REPLACE_CS" != "si" ]; then
        SKIP_CS="true"
    fi
fi

if [ "$SKIP_CS" != "true" ]; then
    echo ""
    echo -e "${W}   CÓMO OBTENER EL CONTENIDO:${N}"
    echo ""
    echo "   1. Ve a console.cloud.google.com"
    echo "   2. APIs → Credenciales → tu OAuth 2.0"
    echo "   3. DESCARGAR JSON"
    echo "   4. Abre el archivo descargado con un"
    echo "      editor de texto (Notepad, VS Code, etc)"
    echo "   5. COPIA TODO el contenido"
    echo "      (empieza con { y termina con })"
    echo ""
    echo -e "${Y}   PEGA aquí el contenido JSON completo${N}"
    echo -e "${Y}   y luego presiona ENTER + CTRL+D:${N}"
    echo ""

    CS_CONTENT=""
    while IFS= read -r line; do
        CS_CONTENT="${CS_CONTENT}${line}"
    done

    if [ -z "$CS_CONTENT" ]; then
        echo -e "${R}   ❌ No pegaste nada${N}"
        echo "   Intenta de nuevo ejecutando el script"
        exit 1
    fi

    # Validar JSON
    echo "$CS_CONTENT" | python -m json.tool > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "${R}   ❌ JSON inválido. Verifica que${N}"
        echo "   copiaste todo el contenido correctamente"
        echo "   Debe empezar con { y terminar con }"
        exit 1
    fi

    echo "$CS_CONTENT" > "$CLIENT"
    chmod 600 "$CLIENT"
    echo -e "${G}   ✅ client_secret.json guardado${N}"
fi

# ═══════════════════════════════════════
# CONFIGURACIÓN
# ═══════════════════════════════════════
echo ""
echo -e "${W}${C}══════════════════════════════════════════════════${N}"
echo -e "${W}  ⚙️ CONFIGURACIÓN${N}"
echo -e "${C}══════════════════════════════════════════════════${N}"

SKIP_CFG=""
if [ -f "$CONFIG" ]; then
    echo -e "${G}   📂 Config guardada encontrada${N}"
    echo -n "   ¿Usar guardada? [s/n] (Enter=s): "
    read USE_OLD
    if [ "$USE_OLD" != "n" ] && [ "$USE_OLD" != "no" ]; then
        SKIP_CFG="true"
    fi
fi

if [ "$SKIP_CFG" != "true" ]; then
    echo ""
    echo -e "${W}🔑 API KEYS${N}"
    echo "────────────────────────────────"
    echo -n "   OpenRouter API Key: "
    read -s OR_KEY
    echo ""
    while [ -z "$OR_KEY" ]; do
        echo -n "   ⚠️ Obligatorio: "
        read -s OR_KEY
        echo ""
    done

    echo -n "   Pexels API Key: "
    read -s PX_KEY
    echo ""
    while [ -z "$PX_KEY" ]; do
        echo -n "   ⚠️ Obligatorio: "
        read -s PX_KEY
        echo ""
    done

    echo ""
    echo -e "${W}📝 BLOGGER${N}"
    echo "────────────────────────────────"
    echo -n "   Blog ID: "
    read BID
    while [ -z "$BID" ]; do
        echo -n "   ⚠️ Obligatorio: "
        read BID
    done

    echo ""
    echo -e "${W}🤖 MODELO IA${N}"
    echo "────────────────────────────────"
    echo "   1. deepseek/deepseek-chat"
    echo "   2. openai/gpt-4o-mini"
    echo "   3. google/gemini-2.0-flash-001"
    echo "   4. anthropic/claude-sonnet-4"
    echo "   5. Otro"
    echo -n "   [1-5] (Enter=1): "
    read MCHOICE
    case "$MCHOICE" in
        2) MNAME="openai/gpt-4o-mini" ;;
        3) MNAME="google/gemini-2.0-flash-001" ;;
        4) MNAME="anthropic/claude-sonnet-4" ;;
        5) echo -n "   Modelo: "; read MNAME ;;
        *) MNAME="deepseek/deepseek-chat" ;;
    esac

    echo ""
    echo -e "${W}📰 CATEGORÍAS${N}"
    echo "────────────────────────────────"
    echo "   1. World News"
    echo "   2. Technology"
    echo "   3. Entertainment"
    echo "   4. Science"
    echo "   5. Business"
    echo "   6. TODAS"
    echo -n "   Elige (ej: 1,2,3) Enter=todas: "
    read CATS
    [ -z "$CATS" ] || [ "$CATS" = "6" ] && CATS="1,2,3,4,5"

    echo ""
    echo -e "${W}📊 CANTIDAD Y FRECUENCIA${N}"
    echo "────────────────────────────────"
    echo ""
    echo "   ¿Cuántas noticias por categoría en"
    echo "   cada ejecución?"
    echo -n "   [1-10] (Enter=1): "
    read NPC
    [ -z "$NPC" ] && NPC=1
    # Validar
    case "$NPC" in
        [1-9]|10) ;;
        *) NPC=1 ;;
    esac

    echo ""
    echo "   ¿Máximo total de noticias por ejecución?"
    echo "   (Límite de seguridad)"
    echo -n "   [1-50] (Enter=10): "
    read MAXP
    [ -z "$MAXP" ] && MAXP=10
    case "$MAXP" in
        [1-9]|[1-4][0-9]|50) ;;
        *) MAXP=10 ;;
    esac

    echo ""
    echo "   ¿Segundos de espera entre cada publicación?"
    echo -n "   [10-300] (Enter=30): "
    read DLY
    [ -z "$DLY" ] && DLY=30
    if [ "$DLY" -lt 10 ] 2>/dev/null; then DLY=10; fi
    if [ "$DLY" -gt 300 ] 2>/dev/null; then DLY=300; fi

    echo ""
    echo "   ¿Publicar como borrador o directo?"
    echo "   1. Borrador (reviso antes)"
    echo "   2. Publicar directo"
    echo -n "   [1/2] (Enter=1): "
    read DRAFTC
    [ "$DRAFTC" = "2" ] && DRAFT="false" || DRAFT="true"

    echo ""
    echo -e "${W}⏰ PROGRAMACIÓN AUTOMÁTICA${N}"
    echo "────────────────────────────────"
    echo ""
    echo "   ¿Cada cuánto tiempo ejecutar?"
    echo ""
    echo "   1. Cada 30 minutos"
    echo "   2. Cada 1 hora"
    echo "   3. Cada 2 horas"
    echo "   4. Cada 3 horas"
    echo "   5. Cada 6 horas"
    echo "   6. Cada 12 horas"
    echo "   7. Una vez al día (9:00 AM)"
    echo "   8. Personalizado (yo pongo los minutos)"
    echo "   9. No programar (solo manual)"
    echo ""
    echo -n "   [1-9] (Enter=2): "
    read SCHED
    [ -z "$SCHED" ] && SCHED=2

    CRON_EXPR=""
    SCHED_DESC=""
    case "$SCHED" in
        1) CRON_EXPR="*/30 * * * *"; SCHED_DESC="Cada 30 minutos" ;;
        2) CRON_EXPR="0 * * * *"; SCHED_DESC="Cada 1 hora" ;;
        3) CRON_EXPR="0 */2 * * *"; SCHED_DESC="Cada 2 horas" ;;
        4) CRON_EXPR="0 */3 * * *"; SCHED_DESC="Cada 3 horas" ;;
        5) CRON_EXPR="0 */6 * * *"; SCHED_DESC="Cada 6 horas" ;;
        6) CRON_EXPR="0 */12 * * *"; SCHED_DESC="Cada 12 horas" ;;
        7) CRON_EXPR="0 9 * * *"; SCHED_DESC="Diario 9:00 AM" ;;
        8)
            echo -n "   Cada cuántos minutos [5-1440]: "
            read CUSTOM_MIN
            [ -z "$CUSTOM_MIN" ] && CUSTOM_MIN=60
            if [ "$CUSTOM_MIN" -lt 5 ] 2>/dev/null; then CUSTOM_MIN=5; fi
            if [ "$CUSTOM_MIN" -ge 60 ] 2>/dev/null; then
                HOURS=$((CUSTOM_MIN / 60))
                if [ $((CUSTOM_MIN % 60)) -eq 0 ]; then
                    CRON_EXPR="0 */$HOURS * * *"
                else
                    CRON_EXPR="*/$CUSTOM_MIN * * * *"
                fi
            else
                CRON_EXPR="*/$CUSTOM_MIN * * * *"
            fi
            SCHED_DESC="Cada $CUSTOM_MIN minutos"
            ;;
        9) CRON_EXPR=""; SCHED_DESC="Solo manual" ;;
        *) CRON_EXPR="0 * * * *"; SCHED_DESC="Cada 1 hora" ;;
    esac

    # Guardar config
    cat > "$CONFIG" << CFGEOF
{
    "openrouter_key": "$OR_KEY",
    "pexels_key": "$PX_KEY",
    "blog_id": "$BID",
    "model": "$MNAME",
    "posts_per_category": $NPC,
    "max_posts": $MAXP,
    "delay": $DLY,
    "draft": $DRAFT,
    "categories": "$CATS",
    "cron_expr": "$CRON_EXPR",
    "schedule_desc": "$SCHED_DESC"
}
CFGEOF
    chmod 600 "$CONFIG"
    echo -e "${G}   💾 Configuración guardada${N}"
fi

# ═══════════════════════════════════════
# LEER CONFIG GUARDADA
# ═══════════════════════════════════════
OR_KEY=$(python3 -c "import json;print(json.load(open('$CONFIG'))['openrouter_key'])")
PX_KEY=$(python3 -c "import json;print(json.load(open('$CONFIG'))['pexels_key'])")
BID=$(python3 -c "import json;print(json.load(open('$CONFIG'))['blog_id'])")
MNAME=$(python3 -c "import json;print(json.load(open('$CONFIG'))['model'])")
NPC=$(python3 -c "import json;print(json.load(open('$CONFIG'))['posts_per_category'])")
MAXP=$(python3 -c "import json;print(json.load(open('$CONFIG'))['max_posts'])")
DLY=$(python3 -c "import json;print(json.load(open('$CONFIG'))['delay'])")
DRAFT=$(python3 -c "import json;print(json.load(open('$CONFIG'))['draft'])")
CATS=$(python3 -c "import json;print(json.load(open('$CONFIG'))['categories'])")
CRON_EXPR=$(python3 -c "import json;print(json.load(open('$CONFIG')).get('cron_expr',''))")
SCHED_DESC=$(python3 -c "import json;print(json.load(open('$CONFIG')).get('schedule_desc','Manual'))")

echo ""
echo -e "${C}══════════════════════════════════════════════════${N}"
echo -e "${W}  RESUMEN${N}"
echo -e "${C}══════════════════════════════════════════════════${N}"
echo "   🔑 OpenRouter: ****${OR_KEY: -6}"
echo "   🔑 Pexels:     ****${PX_KEY: -6}"
echo "   📝 Blog ID:    $BID"
echo "   🤖 Modelo:     $MNAME"
echo "   📰 Categorías: $CATS"
echo "   📊 Por cat:    $NPC noticias"
echo "   📊 Máximo:     $MAXP noticias"
echo "   ⏳ Delay:       ${DLY}s entre posts"
[ "$DRAFT" = "true" ] && echo "   📋 Modo:        BORRADOR" || echo "   📋 Modo:        DIRECTO"
echo "   ⏰ Frecuencia:  $SCHED_DESC"
echo "   📤 Credenciales: $([ -f $CLIENT ] && echo '✅' || echo '❌')"
echo "   🔑 Token:       $([ -f $TOKEN ] && echo '✅ guardado' || echo '⏳ pendiente')"
echo -e "${C}══════════════════════════════════════════════════${N}"

echo ""
echo -n "   ¿Ejecutar ahora? [s/n] (Enter=s): "
read GORUN
if [ "$GORUN" = "n" ] || [ "$GORUN" = "no" ]; then
    echo -e "${Y}   Cancelado${N}"
    deactivate 2>/dev/null
    exit 0
fi

# ═══════════════════════════════════════
# GENERAR ENGINE PYTHON
# ═══════════════════════════════════════
echo ""
echo -e "${B}🐍 Generando motor...${N}"

cat > "$ENGINE" << 'PYEOF'
import feedparser
import requests
from bs4 import BeautifulSoup
import random, hashlib, json, os, re, sys, time
from datetime import datetime, timezone
from urllib.parse import urlparse, parse_qs
from openai import OpenAI
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request as GReq
from googleapiclient.discovery import build

DIR = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(DIR, "data")
CONFIG = os.path.join(DATA, "config.json")
HISTORY = os.path.join(DATA, "posted_history.json")
TOKEN = os.path.join(DATA, "blogger_token.json")
CLIENT = os.path.join(DATA, "client_secret.json")
BLOG_NAME = "Yoelmod"

with open(CONFIG) as f:
    CFG = json.load(f)

OR_KEY = CFG["openrouter_key"]
PX_KEY = CFG["pexels_key"]
BLOG_ID = CFG["blog_id"]
MODEL = CFG["model"]
PPC = int(CFG["posts_per_category"])
MAXP = int(CFG["max_posts"])
DELAY = int(CFG["delay"])
DRAFT = CFG["draft"]
SELCATS = str(CFG["categories"]).split(",")

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
CMAP = {"1":"World News","2":"Technology","3":"Entertainment","4":"Science","5":"Business"}
RSS = {}
for n in SELCATS:
    cn = CMAP.get(n.strip())
    if cn and cn in ALL_FEEDS:
        RSS[cn] = ALL_FEEDS[cn]
if not RSS:
    RSS = ALL_FEEDS.copy()

def utcnow():
    return datetime.now(timezone.utc)
def tstr():
    return utcnow().strftime("%Y-%m-%d %H:%M UTC")
def dstr():
    return utcnow().strftime("%B %d, %Y")
def log(m):
    ts = utcnow().strftime("%H:%M:%S")
    print("[" + ts + "] " + m, flush=True)

class Scraper:
    def __init__(self):
        self.ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/125.0.0.0"
        self.hist = self._ld()
    def _ld(self):
        if os.path.exists(HISTORY):
            with open(HISTORY) as f:
                return set(json.load(f))
        return set()
    def _sv(self):
        with open(HISTORY, "w") as f:
            json.dump(list(self.hist), f)
    def _h(self, t):
        return hashlib.md5(t.lower().strip().encode()).hexdigest()
    def _cl(self, t):
        return BeautifulSoup(t, "html.parser").get_text().strip() if t else ""
    def _ft(self, url):
        try:
            r = requests.get(url, headers={"User-Agent": self.ua}, timeout=15)
            r.raise_for_status()
            s = BeautifulSoup(r.text, "lxml")
            for t in s.find_all(["script","style","nav","footer","header","aside","iframe"]):
                t.decompose()
            b = s.find("article")
            if not b:
                b = s.find("div", class_=lambda x: x and any(k in str(x).lower() for k in ["article","content","story","post-body"]))
            if not b:
                b = s.body
            ps = b.find_all("p") if b else []
            sk = ["cookie","subscribe","newsletter","advertisement","copyright","read more","click here","terms of","sign up","all rights"]
            parts = []
            for p in ps:
                tx = p.get_text().strip()
                if len(tx) > 40 and not any(x in tx.lower() for x in sk):
                    parts.append(tx)
            return " ".join(parts[:25])[:5000]
        except:
            return ""
    def mark(self, h):
        self.hist.add(h)
        self._sv()
    def fetch(self):
        all_news = []
        for cat, feeds in RSS.items():
            log("  📡 " + cat)
            bkt = []
            for fu in feeds:
                try:
                    fd = feedparser.parse(fu)
                    src = fd.feed.get("title", fu.split("/")[2])
                    for e in fd.entries[:10]:
                        t = e.get("title","").strip()
                        if not t:
                            continue
                        h = self._h(t)
                        if h in self.hist:
                            continue
                        lk = e.get("link","")
                        sm = self._cl(e.get("summary",""))[:500]
                        fl = self._ft(lk)
                        bkt.append({"title":t,"link":lk,"summary":sm,"full_content":fl,"source_name":src,"source_url":lk,"category":cat,"hash":h})
                except Exception as ex:
                    log("     ⚠️ " + str(ex)[:60])
            random.shuffle(bkt)
            sel = bkt[:PPC]
            all_news.extend(sel)
            log("     ✅ " + str(len(sel)) + " noticias")
        return all_news

class Generator:
    def __init__(self):
        self.ai = OpenAI(base_url="https://openrouter.ai/api/v1", api_key=OR_KEY)
        self.personas = [
            "Senior Editor at The Economist. Elegant prose, sharp analysis.",
            "Content Strategist at Vox. Immersive reading experiences.",
            "Executive Editor at BBC Future. Authoritative, human story.",
            "Editorial Director at Reuters. Precision with polish.",
            "Features Editor at Wired. Intelligent without pretension.",
        ]
    def gen(self, news):
        p = random.choice(self.personas)
        sb = ("=== SOURCE ===\nPublication: " + news["source_name"]
              + "\nURL: " + news["source_url"]
              + "\nHeadline: " + news["title"]
              + "\nCategory: " + news["category"]
              + "\nSummary: " + news["summary"]
              + "\nFull Text:\n" + (news["full_content"][:3500] if news["full_content"] else "[Use summary.]")
              + "\n=== END ===\n")
        sm = ("You are a " + p + "\n\nRULES:\n"
              "1. ONLY facts from source. NEVER fabricate.\n"
              "2. Preserve numbers, dates, names exactly.\n"
              "3. NEVER copy verbatim. Rewrite completely.\n"
              "4. Vary sentence lengths naturally.\n"
              "5. Cite source naturally.\n6. Powerful lede.\n"
              "7. Active voice 80%.\n8. Include quotes if available.\n"
              "9. End with implications.\n10. Use contractions.\n"
              "11. HTML: <p> <h2> <strong> <blockquote> <em>. No inline styles.\n\n"
              "BANNED: 'In conclusion','worth noting','remains to be seen',"
              "'time will tell','ever-evolving','dive into','delve into',"
              "'game-changer','paradigm shift','end of the day','first and foremost',"
              "'without further ado','in this article','buckle up','navigate',"
              "'realm of','tapestry','testament to','shockwaves','raises questions',"
              "'growing concern','underscores','sparking debate'.\n\n"
              "NEVER mention AI. English ONLY.\n")
        um = ("Craft a polished article:\n\n" + sb + "\n"
              "RAW JSON ONLY:\n"
              '{"headline":"8-14 word headline",'
              '"subheadline":"15-25 word deck",'
              '"meta_description":"150-160 char SEO",'
              '"article_body":"HTML. Lede + 2-3 h2 sections + closing. 700-1000 words. FACTS FROM SOURCE",'
              '"pull_quote":"Most compelling sentence",'
              '"tags":["t1","t2","t3","t4","t5"],'
              '"image_search_query":"2-4 words Pexels",'
              '"reading_time":"X min read"}')
        try:
            r = self.ai.chat.completions.create(
                model=MODEL, messages=[{"role":"system","content":sm},{"role":"user","content":um}],
                temperature=0.82, top_p=0.88, max_tokens=3500,
                frequency_penalty=0.35, presence_penalty=0.25)
            raw = r.choices[0].message.content.strip()
            return self._p(raw, news)
        except Exception as e:
            log("     ❌ IA: " + str(e))
            return None
    def _p(self, raw, news):
        try:
            c = raw
            if c.startswith("```"):
                c = re.sub(r'^```(?:json)?\s*','',c)
                c = re.sub(r'\s*```\s*$','',c)
            d = json.loads(c)
            d["source_name"]=news["source_name"];d["source_url"]=news["source_url"]
            d["category"]=news["category"];d["hash"]=news["hash"]
            return d
        except:
            return self._r(raw, news)
    def _r(self, t, n):
        try:
            def g(p,d=""):
                m=re.search(p,t,re.DOTALL)
                return m.group(1).strip() if m else d
            hl=g(r'"headline"\s*:\s*"((?:[^"\\]|\\.)*)"',n["title"])
            bd=g(r'"article_body"\s*:\s*"((?:[^"\\]|\\.)*)"',"")
            if not bd: bd="<p>Error.</p>"
            bd=bd.replace("\\n","\n").replace('\\"','"')
            sub=g(r'"subheadline"\s*:\s*"((?:[^"\\]|\\.)*)"',"")
            mt=g(r'"meta_description"\s*:\s*"((?:[^"\\]|\\.)*)"',"")
            iq=g(r'"image_search_query"\s*:\s*"((?:[^"\\]|\\.)*)"',n["category"])
            pq=g(r'"pull_quote"\s*:\s*"((?:[^"\\]|\\.)*)"',"")
            rt=g(r'"reading_time"\s*:\s*"((?:[^"\\]|\\.)*)"',"4 min read")
            tm=re.search(r'"tags"\s*:\s*\[(.*?)\]',t)
            tgs=[x.strip().strip('"').strip("'") for x in tm.group(1).split(",")] if tm else [n["category"]]
            return {"headline":hl,"subheadline":sub,"article_body":bd,"meta_description":mt,
                    "tags":tgs,"image_search_query":iq,"pull_quote":pq,"reading_time":rt,
                    "source_name":n["source_name"],"source_url":n["source_url"],
                    "category":n["category"],"hash":n["hash"]}
        except:
            return None
    def chk(self, b):
        bad = [r"worth noting",r"in conclusion",r"remains to be seen",r"time will tell",
               r"ever.evolving",r"dive into",r"delve into",r"game.changer",r"paradigm shift",
               r"end of the day",r"first and foremost",r"buckle up",r"realm of",r"tapestry",
               r"testament to",r"shockwaves",r"raises questions",r"growing concern",r"sparking debate"]
        return [p for p in bad if re.search(p,b,re.IGNORECASE)]

class Images:
    def __init__(self):
        self.h = {"Authorization": PX_KEY}
    def find(self, q):
        try:
            r = requests.get("https://api.pexels.com/v1/search", headers=self.h,
                params={"query":q,"orientation":"landscape","size":"large","per_page":10}, timeout=10)
            r.raise_for_status()
            ph = r.json().get("photos",[])
            if ph:
                p = random.choice(ph[:5])
                return {"url":p["src"]["large2x"],"alt":p.get("alt",q),
                        "photographer":p["photographer"],"photographer_url":p["photographer_url"],
                        "pexels_url":p["url"]}
            s = " ".join(q.split()[:2])
            if s != q: return self.find(s)
            return self._d()
        except:
            return self._d()
    def _d(self):
        return {"url":"https://images.pexels.com/photos/518543/pexels-photo-518543.jpeg",
                "alt":"News","photographer":"Pexels","photographer_url":"https://pexels.com",
                "pexels_url":"https://pexels.com"}

class Formatter:
    CS = {
        "World News":{"c":"#C0392B","i":"&#127758;","g":"#e74c3c,#c0392b"},
        "Technology":{"c":"#2471A3","i":"&#128187;","g":"#3498db,#2471a3"},
        "Entertainment":{"c":"#8E44AD","i":"&#127916;","g":"#9b59b6,#8e44ad"},
        "Science":{"c":"#27AE60","i":"&#128300;","g":"#2ecc71,#27ae60"},
        "Business":{"c":"#D35400","i":"&#128202;","g":"#e67e22,#d35400"},
    }
    def fmt(self, a, img):
        ds=dstr();cat=a.get("category","News")
        s=self.CS.get(cat,{"c":"#2C3E50","i":"&#128240;","g":"#34495e,#2c3e50"})
        cl=s["c"];ic=s["i"];gr=s["g"]
        ph=img.get("photographer","Pexels")
        pu=img.get("photographer_url","https://pexels.com")
        px=img.get("pexels_url","https://pexels.com")
        cr = ""
        if ph != "Pexels":
            cr=('<p style="text-align:center;font-size:11px;color:#aaa;margin:8px 0 0 0;'
                'font-family:Arial,sans-serif;">Photo by <a href="'+pu+'" target="_blank" '
                'rel="noopener" style="color:#aaa;text-decoration:underline;">'+ph+'</a> — '
                '<a href="'+px+'" target="_blank" rel="noopener" style="color:#aaa;'
                'text-decoration:underline;">Pexels</a></p>')
        sh=a.get("subheadline","")
        shh=""
        if sh:
            shh=('<p style="font-size:19px;color:#555;font-family:Georgia,serif;line-height:1.6;'
                 'margin:0 0 25px 0;font-style:italic;border-left:3px solid '+cl+';'
                 'padding-left:18px;">'+sh+'</p>')
        pq=a.get("pull_quote","")
        pqh=""
        if pq:
            pqh=('<div style="margin:35px 0;padding:30px 35px;position:relative;'
                 'background:linear-gradient(135deg,#f8f9fa,#fff);border-radius:8px;">'
                 '<div style="position:absolute;top:-15px;left:25px;font-size:60px;color:'
                 +cl+';opacity:0.3;font-family:Georgia,serif;line-height:1;">&ldquo;</div>'
                 '<p style="font-size:22px;font-family:Georgia,serif;font-style:italic;'
                 'color:#2c2c2c;line-height:1.5;margin:0;position:relative;z-index:1;'
                 'padding-top:10px;">'+pq+'</p>'
                 '<div style="width:60px;height:3px;background:'+cl+';margin:18px 0 0 0;'
                 'border-radius:2px;"></div></div>')
        rt=a.get("reading_time","4 min read")
        th=""
        for tg in a.get("tags",[])[:5]:
            th+=('<a style="display:inline-block;background:#f0f2f5;color:#555;padding:6px 16px;'
                 'border-radius:25px;font-size:12px;margin:4px 5px;font-weight:500;'
                 'text-decoration:none;font-family:Arial,sans-serif;border:1px solid #e0e0e0;">'
                 '#'+str(tg)+'</a>')
        sn=a.get("source_name","Source");su=a.get("source_url","#")
        bd=a.get("article_body","");iu=img.get("url","");ia=img.get("alt","")
        h=('<div style="max-width:800px;margin:0 auto;font-family:Georgia,serif;color:#2c2c2c;background:#fff;">'
           '<div style="margin:0 0 30px 0;border-radius:12px;overflow:hidden;box-shadow:0 4px 20px rgba(0,0,0,0.1);">'
           '<img src="'+iu+'" alt="'+ia+'" style="width:100%;height:auto;display:block;" loading="lazy" /></div>'
           +cr
           +'<div style="display:flex;align-items:center;flex-wrap:wrap;gap:12px;margin:20px 0 15px 0;font-family:Arial,sans-serif;">'
           '<span style="background:linear-gradient(135deg,'+gr+');color:#fff;padding:5px 16px;border-radius:25px;'
           'font-weight:700;text-transform:uppercase;font-size:11px;letter-spacing:1.5px;display:inline-flex;'
           'align-items:center;gap:5px;">'+ic+' '+cat+'</span>'
           '<span style="color:#999;font-size:13px;">'+ds+'</span>'
           '<span style="color:#ddd;">|</span>'
           '<span style="color:#999;font-size:13px;">'+rt+'</span></div>'
           '<div style="height:3px;background:linear-gradient(90deg,'+cl+',transparent);border-radius:2px;margin:0 0 25px 0;"></div>'
           +shh
           +'<div style="font-size:18px;line-height:1.95;color:#333;">'
           '<style>.ab h2{font-family:Arial,Helvetica,sans-serif;font-size:24px;font-weight:700;color:#1a1a1a;'
           'margin:35px 0 15px 0;padding-bottom:8px;border-bottom:2px solid '+cl+';line-height:1.3;}'
           '.ab p{margin:0 0 18px 0;}.ab blockquote{margin:25px 0;padding:20px 25px;border-left:4px solid '
           +cl+';background:#fafafa;font-style:italic;color:#444;border-radius:0 8px 8px 0;font-size:17px;'
           'line-height:1.7;}.ab strong{color:#1a1a1a;font-weight:700;}.ab em{color:#555;}'
           '.ab ul,.ab ol{margin:15px 0;padding-left:25px;}.ab li{margin:8px 0;line-height:1.7;}</style>'
           '<div class="ab">'+bd+'</div></div>'
           +pqh
           +'<div style="text-align:center;margin:40px 0;color:#ddd;font-size:20px;letter-spacing:8px;">&bull; &bull; &bull;</div>'
           '<div style="background:linear-gradient(135deg,#f8f9fa,#f0f2f5);border-radius:10px;padding:22px 28px;'
           'margin:25px 0;font-family:Arial,sans-serif;font-size:14px;border:1px solid #e8e8e8;">'
           '<div style="display:flex;align-items:center;gap:10px;margin-bottom:8px;">'
           '<span style="font-size:20px;">&#128240;</span>'
           '<strong style="font-size:14px;color:#333;">Original Source</strong></div>'
           '<a href="'+su+'" target="_blank" rel="noopener nofollow" style="color:'+cl+';'
           'text-decoration:none;font-weight:600;font-size:15px;">'+sn+' &rarr;</a>'
           '<p style="color:#999;font-size:12px;margin:10px 0 0 0;line-height:1.5;">'
           'Independently written and edited based on verified reports.</p></div>'
           '<div style="margin:25px 0 10px 0;padding-top:20px;border-top:1px solid #eee;">'
           '<p style="font-family:Arial,sans-serif;font-size:11px;text-transform:uppercase;'
           'letter-spacing:1.5px;color:#aaa;margin:0 0 10px 0;font-weight:600;">Related Topics</p>'
           +th+'</div>'
           '<div style="margin-top:30px;padding:20px 0;border-top:2px solid #f0f0f0;text-align:center;'
           'font-family:Arial,sans-serif;"><p style="font-size:12px;color:#bbb;margin:0;">'
           +BLOG_NAME+' &mdash; Trusted News, Global Reach</p></div></div>')
        return h

class Publisher:
    SCOPES = ["https://www.googleapis.com/auth/blogger"]
    def __init__(self):
        self.bid = BLOG_ID
        self.svc = None
    def auth(self):
        creds = None
        if os.path.exists(TOKEN):
            try:
                creds = Credentials.from_authorized_user_file(TOKEN, self.SCOPES)
                if creds and creds.valid:
                    self.svc = build("blogger","v3",credentials=creds)
                    bl = self.svc.blogs().get(blogId=self.bid).execute()
                    log("  ✅ Token OK — " + bl["name"])
                    return True
                elif creds and creds.expired and creds.refresh_token:
                    log("  🔄 Renovando...")
                    creds.refresh(GReq())
                    with open(TOKEN,"w") as f: f.write(creds.to_json())
                    self.svc = build("blogger","v3",credentials=creds)
                    bl = self.svc.blogs().get(blogId=self.bid).execute()
                    log("  ✅ Renovado — " + bl["name"])
                    return True
            except Exception as e:
                log("  ⚠️ Token inválido: " + str(e)[:60])
                creds = None
        if not os.path.exists(CLIENT):
            log("  ❌ Falta " + CLIENT)
            return False
        with open(CLIENT) as f: cc = json.load(f)
        if "installed" in cc: cfg=cc["installed"]
        elif "web" in cc: cfg=cc["web"]
        else: log("  ❌ Formato?"); return False
        cid=cfg["client_id"];csec=cfg["client_secret"]
        turi=cfg.get("token_uri","https://oauth2.googleapis.com/token")
        ruri="http://localhost:8085"
        if "web" in cc:
            log("  ⚠️ Tipo Web detectado")
            log("  Agrega http://localhost:8085 en")
            log("  Google Cloud Console → Credenciales")
        scp=" ".join(self.SCOPES)
        aurl=("https://accounts.google.com/o/oauth2/v2/auth?client_id="+cid
              +"&redirect_uri="+ruri+"&response_type=code&scope="+scp
              +"&access_type=offline&prompt=consent")
        log("")
        log("  🔐 AUTENTICACIÓN")
        log("  1. Abre en navegador:")
        log("")
        log("  " + aurl)
        log("")
        log("  2. Inicia sesión → Permitir")
        log("  3. NO CARGA la página (normal)")
        log("  4. Copia la URL de la barra")
        log("")
        ui = input("  5. Pega URL aquí: ").strip()
        if not ui: return False
        code=None
        if "code=" in ui:
            try:
                ps=parse_qs(urlparse(ui).query)
                if "code" in ps: code=ps["code"][0]
            except: pass
            if not code:
                m=re.search(r'code=([^&\s]+)',ui)
                if m: code=m.group(1)
        if not code: code=ui.strip()
        log("  🔄 Token...")
        try:
            tr=requests.post(turi,data={"code":code,"client_id":cid,"client_secret":csec,
                "redirect_uri":ruri,"grant_type":"authorization_code"},timeout=30)
            td=tr.json()
            if "error" in td:
                log("  ❌ " + td.get("error_description",td["error"]))
                return False
            creds=Credentials(token=td["access_token"],refresh_token=td.get("refresh_token"),
                token_uri=turi,client_id=cid,client_secret=csec,scopes=self.SCOPES)
            ts={"token":td["access_token"],"refresh_token":td.get("refresh_token"),
                "token_uri":turi,"client_id":cid,"client_secret":csec,"scopes":self.SCOPES}
            with open(TOKEN,"w") as f: json.dump(ts,f)
            os.chmod(TOKEN, 0o600)
            log("  ✅ Token guardado")
            self.svc=build("blogger","v3",credentials=creds)
            bl=self.svc.blogs().get(blogId=self.bid).execute()
            log("  ✅ Blog: "+bl["name"]+" — "+bl["url"])
            return True
        except Exception as e:
            log("  ❌ " + str(e))
            return False
    def pub(self, title, html, labels=None, draft=True):
        if not self.svc: return None
        p={"kind":"blogger#post","blog":{"id":self.bid},"title":title,"content":html}
        if labels: p["labels"]=labels
        try:
            r=self.svc.posts().insert(blogId=self.bid,body=p,isDraft=draft).execute()
            md="📝 BORRADOR" if draft else "✅ PUBLICADO"
            log("     "+md+": "+title[:50]+"...")
            u=r.get("url","")
            if u: log("     🔗 "+u)
            return r
        except Exception as e:
            log("     ❌ "+str(e))
            return None

def run():
    log("")
    log("=" * 55)
    log("  🚀 YOELMOD — " + tstr())
    log("  Modelo: " + MODEL)
    modo = "BORRADOR" if DRAFT else "DIRECTO"
    log("  Modo: " + modo)
    log("  Por categoría: " + str(PPC))
    log("  Máximo: " + str(MAXP))
    log("=" * 55)

    sc=Scraper(); gn=Generator(); im=Images(); fm=Formatter(); pb=Publisher()

    log("\n🔐 Autenticando...")
    if not pb.auth():
        log("❌ Auth fallida")
        return

    log("\n📡 Buscando noticias...")
    nl=sc.fetch()
    if not nl:
        log("❌ Sin noticias nuevas")
        return

    td=nl[:MAXP]
    total=len(td)
    log("\n📝 "+str(total)+" artículos\n")

    ok=0;fl=0
    for i,n in enumerate(td):
        nm=str(i+1)+"/"+str(total)
        log("-"*50)
        log("📰 ["+nm+"] "+n["title"][:50]+"...")
        log("   "+n["source_name"]+" | "+n["category"])

        log("   🤖 Generando...")
        a=gn.gen(n)
        if not a: fl+=1; continue

        w=gn.chk(a.get("article_body",""))
        if w: log("   ⚠️ "+", ".join(w[:3]))

        log("   ✅ "+a["headline"][:45]+"...")

        log("   🖼️ Imagen...")
        q=a.get("image_search_query",n["category"])
        img=im.find(q)
        log("   ✅ "+img["photographer"])

        log("   🎨 Diseñando...")
        html=fm.fmt(a,img)

        log("   📤 Publicando...")
        lb=list(set([n["category"]]+a.get("tags",[])[:3]))
        r=pb.pub(title=a["headline"],html=html,labels=lb,draft=DRAFT)

        if r: ok+=1; sc.mark(n["hash"])
        else: fl+=1

        if i<total-1:
            w=random.uniform(DELAY,DELAY*1.5)
            log("   ⏳ "+str(int(w))+"s...")
            time.sleep(w)

    log("")
    log("="*55)
    log("  📊 RESUMEN — "+tstr())
    log("  ✅ "+str(ok)+" exitosos")
    log("  ❌ "+str(fl)+" fallidos")
    log("  Modo: "+modo)
    log("="*55)

if __name__=="__main__":
    run()
PYEOF

echo -e "${G}   ✅ Motor generado${N}"

# ═══════════════════════════════════════
# EJECUTAR
# ═══════════════════════════════════════
echo ""
echo -e "${W}${C}══════════════════════════════════════════════════${N}"
echo -e "${W}  🚀 EJECUTANDO${N}"
echo -e "${C}══════════════════════════════════════════════════${N}"
echo ""

python "$ENGINE"
EXITCODE=$?

# ═══════════════════════════════════════
# CONFIGURAR CRON
# ═══════════════════════════════════════
if [ $EXITCODE -eq 0 ] && [ -n "$CRON_EXPR" ]; then

    # Crear runner silencioso
    cat > "$RUNNER" << RNEOF
#!/bin/bash
source $VENV/bin/activate
python $ENGINE >> $LOGFILE 2>&1
deactivate
RNEOF
    chmod +x "$RUNNER"

    # Leer CRON_EXPR de config si vino de guardada
    if [ -z "$CRON_EXPR" ]; then
        CRON_EXPR=$(python3 -c "import json;print(json.load(open('$CONFIG')).get('cron_expr',''))")
    fi

    if [ -n "$CRON_EXPR" ]; then
        crontab -l 2>/dev/null | grep -v "$RUNNER" | crontab - 2>/dev/null
        (crontab -l 2>/dev/null; echo "$CRON_EXPR $RUNNER") | crontab -

        echo ""
        echo -e "${G}   ✅ Cron configurado: $SCHED_DESC${N}"
        echo "   Ver: crontab -l"
        echo "   Logs: tail -f $LOGFILE"
    fi
elif [ $EXITCODE -eq 0 ]; then
    CRON_EXPR=$(python3 -c "import json;print(json.load(open('$CONFIG')).get('cron_expr',''))" 2>/dev/null)
    if [ -n "$CRON_EXPR" ] && [ "$CRON_EXPR" != "" ]; then
        cat > "$RUNNER" << RNEOF2
#!/bin/bash
source $VENV/bin/activate
python $ENGINE >> $LOGFILE 2>&1
deactivate
RNEOF2
        chmod +x "$RUNNER"
        crontab -l 2>/dev/null | grep -v "$RUNNER" | crontab - 2>/dev/null
        (crontab -l 2>/dev/null; echo "$CRON_EXPR $RUNNER") | crontab -
        SCHED_DESC=$(python3 -c "import json;print(json.load(open('$CONFIG')).get('schedule_desc',''))" 2>/dev/null)
        echo ""
        echo -e "${G}   ✅ Cron: $SCHED_DESC${N}"
    fi
fi

deactivate 2>/dev/null

echo ""
echo -e "${C}══════════════════════════════════════════════════${N}"
echo -e "${W}  COMANDOS ÚTILES${N}"
echo -e "${C}══════════════════════════════════════════════════${N}"
echo ""
echo "  Ejecutar manualmente:"
echo "    ~/autoblogger/autoblogger.sh"
echo ""
echo "  Ver logs:"
echo "    tail -f ~/autoblogger/data/autoblogger.log"
echo ""
echo "  Ver cron:"
echo "    crontab -l"
echo ""
echo "  Parar automático:"
echo "    crontab -l | grep -v run_auto | crontab -"
echo ""
echo "  Borrar historial:"
echo "    rm ~/autoblogger/data/posted_history.json"
echo ""
echo "  Reconfigurar todo:"
echo "    rm ~/autoblogger/data/config.json"
echo "    ~/autoblogger/autoblogger.sh"
echo ""
echo "  Cambiar client_secret.json:"
echo "    rm ~/autoblogger/data/client_secret.json"
echo "    ~/autoblogger/autoblogger.sh"
echo ""
echo "  Ver posts publicados:"
echo "    cat ~/autoblogger/data/posted_history.json"
echo ""
echo -e "${W}${G}  ✅ YOELMOD AUTO BLOGGER — FIN${N}"
echo -e "${C}══════════════════════════════════════════════════${N}"
MAINEOF

chmod +x ~/autoblogger/autoblogger.sh
echo "✅ Script creado. Ejecuta con:"
echo "   ~/autoblogger/autoblogger.sh"
