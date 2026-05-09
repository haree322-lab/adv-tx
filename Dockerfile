FROM python:3.11-slim

# 1. Install system dependencies
RUN apt-get update && apt-get install -y \
    ffmpeg \
    aria2 \
    curl \
    wget \
    gnupg \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# 2. Install Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 3. Copy Python requirements
COPY requirements.txt .

# 4. Clean Python Installation
# First, install base requirements
RUN pip install --no-cache-dir -r requirements.txt

# Next, explicitly force-install the fork (pyrofork) and pyromod to guarantee the .ask() method works.
# This replaces the 5 conflicting pip install lines you had previously.
RUN pip install --no-cache-dir --force-reinstall pyrofork==2.2.11 tgcrypto==1.2.5 pyromod==1.5.0

# 5. Sanity Check (Ensures the build stops if the wrong pyrogram installed)
RUN python3 -c "import pyrogram, pyromod; assert hasattr(pyrogram.Client, 'ask'), 'FATAL: pyromod not patching!'"

# 6. Install Bento4 / mp4decrypt
RUN curl -L "https://www.bok.net/Bento4/binaries/Bento4-SDK-1-6-0-641.x86_64-unknown-linux.zip" \
        -o /tmp/bento4.zip && \
    python3 -c "\
import zipfile, os; \
z = zipfile.ZipFile('/tmp/bento4.zip'); \
matches = [n for n in z.namelist() if 'mp4decrypt' in n and not n.endswith('/')]; \
data = z.read(matches[0]); \
open('/app/mp4decrypt', 'wb').write(data); \
os.chmod('/app/mp4decrypt', 0o755)" && \
    rm /tmp/bento4.zip

# 7. Copy application files
COPY *.py .
COPY database.json .
COPY supervisord.conf /etc/supervisor/conf.d/app.conf

# 8. Setup directories and permissions
RUN mkdir -p downloads && chmod 755 mp4decrypt 2>/dev/null || true

ENV PYTHONUNBUFFERED=1

EXPOSE 5000

# 9. Start command (This MUST be the very last line in the file)
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/conf.d/app.conf"]
