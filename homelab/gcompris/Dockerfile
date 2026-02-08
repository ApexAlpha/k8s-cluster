FROM kasmweb/core-ubuntu-jammy:1.18.0@sha256:514b4ed2199fe37cc1b9405475f5d103c34439dacf176973cd5f040c8bf472bf

USER root

ENV HOME=/home/kasm-default-profile
ENV STARTUPDIR=/dockerstartup
WORKDIR $HOME

# ── Install GCompris-Qt + Dutch locale ──────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        gcompris-qt \
        language-pack-nl \
        locales \
        fonts-noto \
    && locale-gen nl_NL.UTF-8 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ── Pre-set Dutch as UI language ────────────────────────────────────
ENV LANG=nl_NL.UTF-8
ENV LC_ALL=nl_NL.UTF-8

# ── Auto-launch GCompris via XFCE autostart ─────────────────────────
RUN mkdir -p $HOME/.config/autostart && \
    printf '[Desktop Entry]\nType=Application\nName=GCompris\nExec=Exec=/usr/games/gcompris-qt --fullscreen\nIcon=gcompris-qt\nTerminal=false\nX-GNOME-Autostart-enabled=true\n' \
    > $HOME/.config/autostart/gcompris.desktop && \
    chmod +x $HOME/.config/autostart/gcompris.desktop

# ── Desktop shortcut (backup) ──────────────────────────────────────
RUN mkdir -p $HOME/Desktop && \
    printf '[Desktop Entry]\nType=Application\nName=GCompris Educatief\nExec=Exec=/usr/games/gcompris-qt --fullscreen\nIcon=gcompris-qt\nTerminal=false\nCategories=Education;\n' \
    > $HOME/Desktop/gcompris.desktop && \
    chmod +x $HOME/Desktop/gcompris.desktop

# ── Permissions ─────────────────────────────────────────────────────
RUN chown -R 1000:0 $HOME && \
    $STARTUPDIR/set_user_permission.sh $HOME

ENV HOME=/home/kasm-user
WORKDIR $HOME
RUN mkdir -p $HOME && chown -R 1000:0 $HOME

USER 1000
