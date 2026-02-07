FROM kasmweb/core-ubuntu-jammy:1.16.0

USER root

ENV HOME=/home/kasm-default-profile
ENV STARTUPDIR=/dockerstartup
WORKDIR $HOME

# ── Install GCompris-Qt + Dutch locale ──────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        gcompris-qt \
        language-pack-nl \
        locales \
        fonts-noto-core \
    && locale-gen nl_NL.UTF-8 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ── Pre-set Dutch as UI language ────────────────────────────────────
ENV LANG=nl_NL.UTF-8
ENV LC_ALL=nl_NL.UTF-8

# ── Desktop shortcut (fallback) ────────────────────────────────────
RUN mkdir -p $HOME/Desktop && \
    printf '[Desktop Entry]\n\
Type=Application\n\
Name=GCompris Educatief\n\
Exec=gcompris-qt\n\
Icon=gcompris-qt\n\
Terminal=false\n\
Categories=Education;\n' > $HOME/Desktop/gcompris.desktop && \
    chmod +x $HOME/Desktop/gcompris.desktop

# ── Custom startup: auto-launch GCompris ────────────────────────────
COPY custom_startup.sh $STARTUPDIR/custom_startup.sh
RUN chmod 755 $STARTUPDIR/custom_startup.sh

# ── Permissions ─────────────────────────────────────────────────────
RUN chown -R 1000:0 $HOME && \
    $STARTUPDIR/set_user_permission.sh $HOME

ENV HOME=/home/kasm-user
WORKDIR $HOME
RUN mkdir -p $HOME && chown -R 1000:0 $HOME

USER 1000
