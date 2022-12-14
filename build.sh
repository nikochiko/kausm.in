# download theme if it is not there
test -d "themes/PaperMod/.git" || (git submodule init && git submodule update)

# install hugo if it's not there
if [[ ! -f "$APP_ROOT/bin/hugo" ]]
then
    DOWNLOAD_DIR="$TMPDIR/hugo"
    mkdir "$DOWNLOAD_DIR" && \
    curl -L -o "$DOWNLOAD_DIR/hugo.tar.gz" https://github.com/gohugoio/hugo/releases/download/v0.104.2/hugo_0.104.2_linux-amd64.tar.gz && \
    tar -C "$APP_ROOT/bin" -xvzf "$DOWNLOAD_DIR/hugo.tar.gz" hugo && \
    rm -r "$DOWNLOAD_DIR"

    if [[ $? -ne 0 ]]; then
        echo "something went wrong while installing hugo"
        exit 1
    fi
fi

# build static site with hugo
rm -r "$APP_ROOT/site" && hugo -b http://kaustubh.kaustubh-dev.pipal.in/ -d "$APP_ROOT/site"
