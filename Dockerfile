# === Runtime base =============================================================
# Hardened minimal base: busybox only, no package manager, runs as the
# built-in nonroot user (uid 65532). Named here so the build stage can seed
# its apk database from it.
FROM dhi.io/alpine-base:3.24 AS runtime

# === Build stage: stage the runtime packages into /rootfs =====================
FROM dhi.io/alpine-base:3.24-dev AS packages

# - The apk database is seeded from the runtime image, so packages it already
#   ships (DHI's hardened musl, openssl, busybox, CA bundle) are kept and only
#   missing packages are staged.
# - The DHI hardened repo is the default source (postgresql-client, tzdata,
#   ca-certificates-bundle); stock Alpine is only reachable via the @stock
#   tag, for s3cmd, which DHI does not carry. The Alpine branch is derived
#   from the image's own DHI repo URL so it matches after Renovate bumps.
# - --no-scripts skips install triggers (they would need a shell inside
#   /rootfs), so the postgresql /usr/bin symlinks are created manually.
# - The build fails if a runtime package would be replaced.
# The resulting apk database is kept so scanners (Trivy) see every package.
COPY --from=runtime /lib/apk/db/installed /rootfs/lib/apk/db/installed
RUN set -eu; R=/rootfs; db="$R/lib/apk/db/installed"; \
    pkgs() { awk -F: '/^P:/{p=$2} /^V:/{print p"="$2}' "$db" | sort; }; \
    pkgs > /tmp/runtime.pkgs; \
    mkdir -p "$R/etc/apk"; \
    cp -r /etc/apk/keys "$R/etc/apk/"; \
    sed -n 's/^P://p' "$db" > "$R/etc/apk/world"; \
    dhi="$(grep -m1 '://dhi.io/' /etc/apk/repositories)"; \
    v="$(echo "$dhi" | sed -n 's#.*/alpine/\(v[0-9.]*\)/main$#\1#p')"; \
    test -n "$v"; \
    printf '%s\n@stock https://dl-cdn.alpinelinux.org/alpine/%s/main\n@stock https://dl-cdn.alpinelinux.org/alpine/%s/community\n' \
      "$dhi" "$v" "$v" > "$R/etc/apk/repositories"; \
    apk add --root "$R" --no-cache --no-scripts \
      postgresql-client tzdata ca-certificates-bundle s3cmd@stock; \
    for f in "$R"/usr/libexec/postgresql*/*; do \
      ln -sf "${f#"$R"}" "$R/usr/bin/${f##*/}"; \
    done; \
    pkgs > /tmp/final.pkgs; \
    test -z "$(comm -23 /tmp/runtime.pkgs /tmp/final.pkgs)"; \
    find "$R/lib/apk" -mindepth 1 ! -path "$R/lib/apk/db" ! -path "$db" -exec rm -rf {} +; \
    rm -rf "$R/etc/apk" "$R/var/cache" "$R/etc/passwd" "$R/etc/group" "$R/etc/shadow"

# === Runtime stage ============================================================
FROM runtime

COPY --from=packages /rootfs /

COPY --chmod=755 backup /usr/local/bin/backup
COPY --chmod=755 entrypoint.sh /sbin/entrypoint.sh
# World-readable (it holds no credentials) and located via S3CMD_CONFIG, so
# s3cmd finds it whatever uid the container is run as.
COPY --chmod=644 s3cfg /etc/s3cmd/s3cfg
ENV S3CMD_CONFIG=/etc/s3cmd/s3cfg

USER 65532:65532

CMD ["/sbin/entrypoint.sh"]
