#!/usr/bin/env bash
set -euo pipefail

UPSTREAM="https://github.com/jurerotar/Pillage-First-Ask-Questions-Later.git"
COMMIT="${PILLAGE_FIRST_COMMIT:-54451093040b3934382fa585be2b61f26a653bfb}"
WORKDIR="${PILLAGE_FIRST_WORKDIR:-/tmp/lan-arcade-pillage-first-build}"
DEST="${PILLAGE_FIRST_DEST:-/var/www/html/mirrors/pillage-first}"
PREFIX="${PILLAGE_FIRST_PREFIX:-/mirrors/pillage-first}"
export PREFIX

case "$(readlink -f "$DEST" 2>/dev/null || echo "$DEST")" in
  /var/www/html/mirrors/pillage-first|/var/www/html/mirrors/pillage-first/*|/var/www/html/mirrors/pillage-first-*) ;;
  *) echo "Refusing unexpected destination: $DEST" >&2; exit 1 ;;
esac

case "$PREFIX" in
  /mirrors/pillage-first|/mirrors/pillage-first/*|/mirrors/pillage-first-*) ;;
  *) echo "Refusing unexpected prefix: $PREFIX" >&2; exit 1 ;;
esac

if [ ! -d "$WORKDIR/.git" ]; then
  rm -rf "$WORKDIR"
  git clone "$UPSTREAM" "$WORKDIR"
fi
cd "$WORKDIR"
git fetch --depth 1 origin "$COMMIT"
git checkout --detach "$COMMIT"

python3 - <<'PY'
import os
from pathlib import Path
root = Path('.')
prefix = os.environ['PREFIX'].rstrip('/')
app_root = root / 'apps/web/app/root.tsx'
s = app_root.read_text()
s = s.replace("import { WebRTCAdvertiser } from 'app/components/webrtc-advertiser';\n", '')
s = s.replace('      <WebRTCAdvertiser />\n', '')
app_root.write_text(s)

vite = root / 'apps/web/vite.config.ts'
s = vite.read_text()
s = s.replace("  start_url: '/',", f"  start_url: '{prefix}/',")
s = s.replace("      src: `/favicon/web-app-manifest-192x192.png?v=${graphicsVersion}`,", f"      src: `{prefix}/favicon/web-app-manifest-192x192.png?v=${{graphicsVersion}}`,", 1)
s = s.replace("      src: `/favicon/web-app-manifest-512x512.png?v=${graphicsVersion}`,", f"      src: `{prefix}/favicon/web-app-manifest-512x512.png?v=${{graphicsVersion}}`,", 1)
s = s.replace("  scope: '/',", f"  scope: '{prefix}/',")
s = s.replace("const viteConfig = defineViteConfig({\n", f"const viteConfig = defineViteConfig({{\n  base: '{prefix}/',\n", 1)
vite.write_text(s)

hook = root / 'apps/web/app/(public)/hooks/use-github-stars.ts'
hook.write_text("""import { useQuery } from '@tanstack/react-query';\n\nexport const useGithubStars = () => {\n  return useQuery({\n    queryKey: ['github-stars', 'lan-arcade-offline'],\n    queryFn: async () => ({\n      starCount: undefined,\n      forkCount: undefined,\n      watcherCount: undefined,\n    }),\n    staleTime: Infinity,\n  });\n};\n""")

discord_hook = root / 'apps/web/app/(public)/hooks/use-discord-members.ts'
discord_hook.write_text("""import { useQuery } from '@tanstack/react-query';\n\nexport const useDiscordMembers = () => {\n  return useQuery({\n    queryKey: ['discord-members', 'lan-arcade-offline'],\n    queryFn: async () => ({\n      memberCount: 217,\n    }),\n    placeholderData: {\n      memberCount: 217,\n    },\n    staleTime: Infinity,\n  });\n};\n""")

rally_point = root / 'apps/web/app/(game)/(village-slug)/(village)/(...building-field-id)/components/components/rally-point/rally-point-send-troops.tsx'
s = rally_point.read_text()
if 'AttackRaidForm' not in s:
    s = s.replace(
        "import { FoundNewVillageForm } from 'app/(game)/(village-slug)/components/send-troops/found-new-village-form';\n",
        "import { AttackRaidForm } from 'app/(game)/(village-slug)/components/send-troops/attack-raid-form';\n"
        "import { FoundNewVillageForm } from 'app/(game)/(village-slug)/components/send-troops/found-new-village-form';\n",
    )
s = s.replace("// import { AttackRaidForm } from './send-troops/attack-raid-form';\n", '')
s = s.replace(
    "const tabs = [\n  // 'attack-or-raid',\n  'reinforce-or-relocate',",
    "const tabs = [\n  'attack-or-raid',\n  'reinforce-or-relocate',",
)
s = s.replace(
    "          {/*<Tab value=\"attack-or-raid\">{t('Attack or raid')}</Tab>*/}",
    "          <Tab value=\"attack-or-raid\">{t('Attack or raid')}</Tab>",
)
s = s.replace(
    "        {/*<TabPanel value=\"attack-or-raid\">*/}\n        {/*  <AttackRaidForm />*/}\n        {/*</TabPanel>*/}",
    "        <TabPanel value=\"attack-or-raid\">\n          <AttackRaidForm />\n        </TabPanel>",
)
if 'AttackRaidForm' not in s or '<Tab value="attack-or-raid">' not in s:
    raise SystemExit('Failed to expose Rally Point attack/raid tab')
rally_point.write_text(s)

tile_modal = root / 'apps/web/app/(game)/(village-slug)/(map)/components/tile-modal.tsx'
s = tile_modal.read_text()
if 'rally-point-send-troops-tab=attack-or-raid' not in s:
    s = s.replace(
        "        {!isOwnedByPlayer && <Text>{t('No actions available')}</Text>}",
        """        {!isOwnedByPlayer && (
          <Text variant=\"link\">
            <Link
              to={`${getVillageBasePath(currentVillage.slug)}/village/39?tab=send-troops&rally-point-send-troops-tab=attack-or-raid&x=${tile.coordinates.x}&y=${tile.coordinates.y}`}
            >
              {t('Attack or raid')}
            </Link>
          </Text>
        )}""",
    )
if 'rally-point-send-troops-tab=attack-or-raid' not in s:
    raise SystemExit('Failed to expose map attack/raid action')
if 'const TileModalTroopIntel' not in s:
    s = s.replace(
        "const TileModalPlayerInfo = ({ tile }: TileModalProps) => {",
        """const TileModalTroopIntelSkeleton = () => {
  return (
    <div className=\"flex flex-wrap gap-2\">
      {Array.from({ length: 5 }, (_, i) => (
        <Skeleton
          // biome-ignore lint/suspicious/noArrayIndexKey: It's a static loading placeholder.
          key={`troop-intel-skeleton-${i}`}
          className=\"h-5 w-12 rounded-xs\"
        />
      ))}
    </div>
  );
};

const TileModalTroopIntel = ({ tile }: TileModalProps) => {
  const { t } = useTranslation();
  const { tileTroops } = useTileTroops(tile.id);

  const visibleTroops = tileTroops.filter(({ amount }) => amount > 0);

  if (visibleTroops.length === 0) {
    return (
      <Text className=\"text-sm text-muted-foreground\">
        {t('No defenders detected')}
      </Text>
    );
  }

  return (
    <div className=\"flex flex-wrap gap-2\">
      {visibleTroops.map(({ unitId, amount }) => (
        <span
          key={unitId}
          className=\"flex items-center gap-1 rounded-xs border border-border px-2 py-1 text-sm\"
        >
          <Icon
            className=\"size-4\"
            type={unitIdToUnitIconMapper(unitId)}
          />
          {amount}
        </span>
      ))}
    </div>
  );
};

const TileModalPlayerInfo = ({ tile }: TileModalProps) => {""",
    )
    s = s.replace(
        "      <TileModalPlayerInfo tile={tile} />\n      <div className=\"flex flex-col gap-2\">",
        """      <TileModalPlayerInfo tile={tile} />
      {!isOwnedByPlayer && (
        <div className=\"flex flex-col gap-2\">
          <Text as=\"h3\">{t('Scout intel')}</Text>
          <Suspense fallback={<TileModalTroopIntelSkeleton />}>
            <TileModalTroopIntel tile={tile} />
          </Suspense>
        </div>
      )}
      <div className=\"flex flex-col gap-2\">""",
    )
if 'const TileModalTroopIntel' not in s or "{t('Scout intel')}" not in s:
    raise SystemExit('Failed to expose map scout intel')
tile_modal.write_text(s)

PY

uid=$(id -u)
gid=$(id -g)
docker run --rm \
  -u "$uid:$gid" \
  -e HOME=/tmp \
  -e npm_config_cache=/tmp/npm-cache \
  -v "$PWD:/work" \
  -w /work \
  node:24-bookworm \
  bash -lc 'npx -y npm@11.16.0 ci --ignore-scripts && npx -y npm@11.16.0 run inject-graphics && npx -y npm@11.16.0 run -w @pillage-first/web build'

python3 - <<'PY'
import os
from pathlib import Path
root = Path('apps/web/build/client')
prefix = os.environ['PREFIX'].rstrip('/')
for path in list(root.rglob('*.html')) + [root / 'manifest.webmanifest']:
    if not path.exists():
        continue
    s = path.read_text()
    replacements = {
        'href="/pillage-first-logo-horizontal.svg': f'href="{prefix}/pillage-first-logo-horizontal.svg',
        'src="/pillage-first-logo-horizontal.svg': f'src="{prefix}/pillage-first-logo-horizontal.svg',
        'href="/manifest.webmanifest': f'href="{prefix}/manifest.webmanifest',
        'href="/favicon/': f'href="{prefix}/favicon/',
        'src="/favicon/': f'src="{prefix}/favicon/',
        'href="/react-icons-sprite-': f'href="{prefix}/react-icons-sprite-',
        'use href="/react-icons-sprite-': f'use href="{prefix}/react-icons-sprite-',
        'src="/landing/': f'src="{prefix}/landing/',
        'srcSet="/landing/': f'srcSet="{prefix}/landing/',
        'srcset="/landing/': f'srcset="{prefix}/landing/',
        'href="/landing/': f'href="{prefix}/landing/',
        'href="/game-worlds': f'href="{prefix}/game-worlds',
        'href="/frequently-asked-questions': f'href="{prefix}/frequently-asked-questions',
        'href="/latest-updates': f'href="{prefix}/latest-updates',
        'href="/get-involved': f'href="{prefix}/get-involved',
        'href="/not-found': f'href="{prefix}/not-found',
        'href="/" data-discover': f'href="{prefix}/" data-discover',
        'href="/"': f'href="{prefix}/"',
        '"basename":"/"': f'"basename":"{prefix}"',
        '"basename":""': f'"basename":"{prefix}"',
        'content="undefined/pillage-first-logo.png': f'content="{prefix}/pillage-first-logo.png',
    }
    for old, new in replacements.items():
        s = s.replace(old, new)
    path.write_text(s)
random_uuid_polyfill = '''(()=>{const g=globalThis;let c=g.crypto;if(!c){try{Object.defineProperty(g,"crypto",{value:{},configurable:true});c=g.crypto;}catch{c={};g.crypto=c;}}const make=()=>{const b=new Uint8Array(16);if(c&&typeof c.getRandomValues==="function")c.getRandomValues(b);else for(let i=0;i<16;i+=1)b[i]=Math.floor(Math.random()*256);b[6]=b[6]&15|64;b[8]=b[8]&63|128;const h=Array.from(b,v=>v.toString(16).padStart(2,"0"));return `${h.slice(0,4).join("")}-${h.slice(4,6).join("")}-${h.slice(6,8).join("")}-${h.slice(8,10).join("")}-${h.slice(10).join("")}`;};if(c&&typeof c.randomUUID!=="function"){try{Object.defineProperty(c,"randomUUID",{value:make,configurable:true});}catch{try{c.randomUUID=make;}catch{}}}})();
'''
def prefix_graphics_pack_urls(text):
    text = text.replace('/graphic-packs/', f'{prefix}/graphic-packs/')
    text = text.replace(f'{prefix}{prefix}/graphic-packs/', f'{prefix}/graphic-packs/')
    return text
for path in root.rglob('*.js'):
    s = path.read_text(errors='ignore')
    ns = s.replace('`/landing/${', '`' + prefix + '/landing/${')
    ns = ns.replace('`/react-icons-sprite-', '`' + prefix + '/react-icons-sprite-')
    ns = ns.replace('\"/react-icons-sprite-', '\"' + prefix + '/react-icons-sprite-')
    ns = ns.replace('\"/landing/', '\"' + prefix + '/landing/')
    ns = ns.replace("'/landing/", "'" + prefix + "/landing/")
    ns = ns.replace('`/pillage-first-logo-horizontal.svg`', '`' + prefix + '/pillage-first-logo-horizontal.svg`')
    ns = ns.replace('\"/pillage-first-logo-horizontal.svg\"', '\"' + prefix + '/pillage-first-logo-horizontal.svg\"')
    ns = ns.replace("'/pillage-first-logo-horizontal.svg'", "'" + prefix + "/pillage-first-logo-horizontal.svg'")
    ns = ns.replace('queryFn:async()=>await(await fetch(`/api/discord-members?code=Ep7NKVXUZA`)).json(),', 'queryFn:async()=>({memberCount:217}),')
    ns = ns.replace('fetch(`/api/discord-members?code=Ep7NKVXUZA`)', 'Promise.resolve({json:async()=>({memberCount:217})})')
    if not ns.startswith('(()=>{const g=globalThis;let c=g.crypto;'):
        ns = random_uuid_polyfill + ns
    ns = prefix_graphics_pack_urls(ns)
    if ns != s:
        path.write_text(ns)
for path in root.rglob('*.css'):
    s = path.read_text(errors='ignore')
    ns = prefix_graphics_pack_urls(s)
    if ns != s:
        path.write_text(ns)
for path in root.rglob('*.map'):
    path.unlink()
PY

STAGE="$(mktemp -d "${DEST}.stage.XXXXXX")"
BACKUP=""
cleanup() {
  if [ -n "${STAGE:-}" ] && [ -d "$STAGE" ]; then
    rm -rf "$STAGE"
  fi
}
trap cleanup EXIT

rsync -a apps/web/build/client/ "$STAGE/"
mkdir -p "$STAGE/landing"
rsync -a .github/assets/image-[1-5]-*-202603240613.* "$STAGE/landing/"
cat > "$STAGE/ATTRIBUTION.txt" <<'EOF'
Pillage First! (Ask Questions Later)
Upstream: https://github.com/jurerotar/Pillage-First-Ask-Questions-Later
Upstream commit mirrored for this LAN build: 54451093040b3934382fa585be2b61f26a653bfb
License: GNU Affero General Public License v3.0 or later (AGPL-3.0-or-later)

LAN Arcade build notes:
- Built with Node 24 in Docker from the upstream source.
- Deployed as a static/offline-first mirror under /mirrors/pillage-first/.
- Patched for GannanNet subpath hosting and disabled automatic PeerJS world advertising on page load to avoid background internet-facing discovery attempts.
- Upstream community/source links remain informational; the playable path does not require an account or internet.

Source cache: /mirrors/games/downloads/native/travian-like/pillage-first/
EOF
touch "$STAGE/.lan-arcade-ready"
test -s "$STAGE/index.html"
test -d "$STAGE/assets"
find "$STAGE/assets" -type f -name '*.js' -print -quit | grep -q .

BACKUP="${DEST}.previous-$(date -u +%Y%m%dT%H%M%SZ)"
if [ -e "$DEST" ]; then
  mv "$DEST" "$BACKUP"
fi
if mv "$STAGE" "$DEST"; then
  STAGE=""
  if [ -n "$BACKUP" ] && [ -e "$BACKUP" ]; then
    rm -rf "$BACKUP"
  fi
else
  if [ -n "$BACKUP" ] && [ -e "$BACKUP" ] && [ ! -e "$DEST" ]; then
    mv "$BACKUP" "$DEST"
  fi
  exit 1
fi

printf 'Pillage First deployed to %s\n' "$DEST"
