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
git reset --hard "$COMMIT"
git clean -fdx

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
if "import { AttackRaidForm } from 'app/(game)/(village-slug)/components/send-troops/attack-raid-form';" not in s:
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
if "import { AttackRaidForm } from 'app/(game)/(village-slug)/components/send-troops/attack-raid-form';" not in s or '<Tab value="attack-or-raid">' not in s:
    raise SystemExit('Failed to expose Rally Point attack/raid tab')
rally_point.write_text(s)

attack_form = root / 'apps/web/app/(game)/(village-slug)/components/send-troops/attack-raid-form.tsx'
s = attack_form.read_text()
if 'const AttackRaidBriefing' not in s:
    s = s.replace(
        "import { type DefaultValues, useFormContext } from 'react-hook-form';",
        "import { Suspense, useEffect, useMemo, useState } from 'react';\nimport { type DefaultValues, useFormContext, useWatch } from 'react-hook-form';",
        1,
    )
    s = s.replace(
        "import { useNavigate } from 'react-router';\n",
        "import { useNavigate } from 'react-router';\nimport { useTileTroops } from 'app/(game)/(village-slug)/(map)/hooks/use-tile-troops';\n",
        1,
    )
    s = s.replace(
        "import { Text } from 'app/components/text';\n",
        "import { Icon } from 'app/components/icon';\nimport { unitIdToUnitIconMapper } from 'app/components/icons/icons';\nimport { Text } from 'app/components/text';\n",
        1,
    )
    s = s.replace(
        "import { RadioGroup, RadioGroupItem } from 'app/components/ui/radio-group';\n",
        "import { RadioGroup, RadioGroupItem } from 'app/components/ui/radio-group';\nimport { Skeleton } from 'app/components/ui/skeleton';\n",
        1,
    )
    s = s.replace(
        "const attackRaidDefaultValues = {\n  action: 'attack_normal',\n} satisfies DefaultValues<AttackRaidFormValues>;\n\n",
        """const attackRaidDefaultValues = {
  action: 'attack_normal',
} satisfies DefaultValues<AttackRaidFormValues>;

const AttackRaidDefenderIntelSkeleton = () => {
  return (
    <div className=\"flex flex-wrap gap-2\">
      {Array.from({ length: 4 }, (_, i) => (
        <Skeleton
          // biome-ignore lint/suspicious/noArrayIndexKey: It's a static loading placeholder.
          key={`attack-briefing-skeleton-${i}`}
          className=\"h-6 w-14 rounded-xs\"
        />
      ))}
    </div>
  );
};

const AttackRaidDefenderIntel = ({ tileId }: { tileId: number }) => {
  const { t } = useTranslation();
  const { tileTroops } = useTileTroops(tileId);

  const visibleTroops = tileTroops.filter(({ amount }) => amount > 0);
  const totalDefenders = visibleTroops.reduce(
    (total, { amount }) => total + amount,
    0,
  );

  if (visibleTroops.length === 0) {
    return (
      <Text className=\"text-sm text-muted-foreground\">
        {t('No defenders detected at this tile.')}
      </Text>
    );
  }

  return (
    <div className=\"flex flex-col gap-2\">
      <Text className=\"text-sm text-muted-foreground\">
        {t('Detected defenders')}: {totalDefenders}
      </Text>
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
    </div>
  );
};

const AttackRaidBriefingShell = () => {
  const { t } = useTranslation();

  return (
    <div className="min-w-64 rounded-md border border-border bg-card/60 p-3">
      <div className="flex flex-col gap-3">
        <div>
          <Text as="h3">{t('Attack briefing')}</Text>
          <Text className="text-sm text-muted-foreground">
            {t('Preparing target intel...')}
          </Text>
        </div>
        <AttackRaidDefenderIntelSkeleton />
      </div>
    </div>
  );
};

const AttackRaidBriefingContent = () => {
  const { t } = useTranslation();
  const { control } = useFormContext<AttackRaidFormValues>();
  const target = useWatch({ control, name: 'target' });
  const units = useWatch({ control, name: 'units' });

  const selectedTroopCount = useMemo(() => {
    return (units ?? []).reduce((total, unit) => total + unit.selected, 0);
  }, [units]);

  const targetTileId = target?.tileId;
  const targetLabel =
    target?.x !== undefined && target?.y !== undefined
      ? `(${target.x}|${target.y})`
      : t('No target selected');

  return (
    <div className="min-w-64 rounded-md border border-border bg-card/60 p-3">
      <div className="flex flex-col gap-3">
        <div>
          <Text as="h3">{t('Attack briefing')}</Text>
          <Text className="text-sm text-muted-foreground">
            {t('Target')}: {targetLabel}
          </Text>
        </div>
        <div>
          <Text className="text-sm text-muted-foreground">
            {t('Selected troops')}: {selectedTroopCount}
          </Text>
          {selectedTroopCount === 0 ? (
            <Text className="text-sm text-warning">
              {t('Select at least one troop before confirming.')}
            </Text>
          ) : null}
        </div>
        <div>
          <Text className="text-sm font-medium">{t('Scout intel')}</Text>
          {targetTileId ? (
            <Suspense fallback={<AttackRaidDefenderIntelSkeleton />}>
              <AttackRaidDefenderIntel tileId={targetTileId} />
            </Suspense>
          ) : (
            <Text className="text-sm text-muted-foreground">
              {t('Choose a target to show defender intel.')}
            </Text>
          )}
        </div>
      </div>
    </div>
  );
};

const AttackRaidBriefing = () => {
  const [isMounted, setIsMounted] = useState(false);

  useEffect(() => {
    setIsMounted(true);
  }, []);

  return isMounted ? <AttackRaidBriefingContent /> : <AttackRaidBriefingShell />;
};

""",
        1,
    )
    s = s.replace(
        "          extraTargetContent={<AttackRaidActionSelector />}\n",
        """          extraTargetContent={
            <div className=\"flex flex-col gap-4\">
              <AttackRaidActionSelector />
              <AttackRaidBriefing />
            </div>
          }
""",
        1,
    )
if 'const AttackRaidBriefing' not in s:
    raise SystemExit('Failed to expose attack briefing')
attack_form.write_text(s)

resolver = root / 'packages/api/src/http/events/resolvers/troop-movement-resolver.ts'
s = resolver.read_text()
if 'calculateRaidCarryCapacity' not in s:
    s = s.replace(
        "import { buildingMap } from '@pillage-first/game-assets/buildings';\n",
        "import { buildingMap } from '@pillage-first/game-assets/buildings';\nimport { getUnitDefinition } from '@pillage-first/game-assets/utils/units';\n",
        1,
    )
    s = s.replace(
        "import { updateVillageResourcesAt } from '../../../utils/village';\n",
        "import {\n  addVillageResourcesAt,\n  subtractVillageResourcesAt,\n  updateVillageResourcesAt,\n} from '../../../utils/village';\n",
        1,
    )
    s = s.replace(
        "import type { Resolver } from '../resolver';\n\nexport const adventureMovementResolver",
        """import type { Resolver } from '../resolver';

type RaidResourceBundle = [number, number, number, number];
type ReturnMovementWithLoot = GameEvent<'troopMovementReturn'> & {
  carriedResources?: RaidResourceBundle;
};

const emptyRaidResourceBundle = (): RaidResourceBundle => [0, 0, 0, 0];

const raidTargetResourcesSchema = z.strictObject({
  villageId: z.number(),
  wood: z.number(),
  clay: z.number(),
  iron: z.number(),
  wheat: z.number(),
});

const calculateRaidCarryCapacity = (troops: GameEvent<'troopMovementRaid'>['troops']) => {
  return troops.reduce((total, { amount, unitId }) => {
    return total + amount * getUnitDefinition(unitId).unitCarryCapacity;
  }, 0);
};

const splitRaidLootByCapacity = (
  resources: RaidResourceBundle,
  carryCapacity: number,
): RaidResourceBundle => {
  if (carryCapacity <= 0) {
    return emptyRaidResourceBundle();
  }

  const loot = emptyRaidResourceBundle();
  let remainingCapacity = Math.floor(carryCapacity);

  for (let i = 0; i < resources.length; i += 1) {
    const remainingSlots = resources.length - i;
    const fairShare = Math.ceil(remainingCapacity / remainingSlots);
    const amount = Math.min(Math.floor(resources[i]), fairShare);
    loot[i] = amount;
    remainingCapacity -= amount;
  }

  return loot;
};

const raidVillageResources = (
  database: Parameters<Resolver<GameEvent<'troopMovementRaid'>>>[0],
  targetTileId: number,
  timestamp: number,
  carryCapacity: number,
): RaidResourceBundle => {
  if (carryCapacity <= 0) {
    return emptyRaidResourceBundle();
  }

  const target = database.selectObject({
    sql: `
      SELECT
        v.id AS villageId,
        rs.wood,
        rs.clay,
        rs.iron,
        rs.wheat
      FROM
        villages v
          JOIN resource_sites rs ON rs.tile_id = v.tile_id
      WHERE
        v.tile_id = $target_tile_id;
    `,
    bind: { $target_tile_id: targetTileId },
    schema: raidTargetResourcesSchema,
  });

  if (!target) {
    return emptyRaidResourceBundle();
  }

  updateVillageResourcesAt(database, target.villageId, timestamp);

  const currentTargetResources = database.selectObject({
    sql: `
      SELECT
        v.id AS villageId,
        rs.wood,
        rs.clay,
        rs.iron,
        rs.wheat
      FROM
        villages v
          JOIN resource_sites rs ON rs.tile_id = v.tile_id
      WHERE
        v.id = $target_village_id;
    `,
    bind: { $target_village_id: target.villageId },
    schema: raidTargetResourcesSchema,
  })!;

  const stolenResources = splitRaidLootByCapacity(
    [
      currentTargetResources.wood,
      currentTargetResources.clay,
      currentTargetResources.iron,
      currentTargetResources.wheat,
    ],
    carryCapacity,
  );

  if (stolenResources.some((amount) => amount > 0)) {
    subtractVillageResourcesAt(
      database,
      target.villageId,
      timestamp,
      stolenResources,
    );
  }

  return stolenResources;
};

export const adventureMovementResolver""",
        1,
    )
    s = s.replace(
        "export const returnMovementResolver: Resolver<\n  GameEvent<'troopMovementReturn'>\n> = (database, args) => {\n  const { villageId, targetTileId, troops } = args;\n\n  addTroops(\n",
        """export const returnMovementResolver: Resolver<
  GameEvent<'troopMovementReturn'>
> = (database, args) => {
  const { villageId, targetTileId, troops, resolvesAt } = args;
  const { carriedResources } = args as ReturnMovementWithLoot;

  if (carriedResources?.some((amount) => amount > 0)) {
    addVillageResourcesAt(database, villageId, resolvesAt, carriedResources);
  }

  addTroops(
""",
        1,
    )
    s = s.replace(
        "  const { villageId, resolvesAt, troops, originTileId, targetTileId } = args;\n\n  // TODO: Combat\n  createEvents<'troopMovementReturn'>(database, {\n    villageId,\n    troops,\n    startsAt: resolvesAt,\n    targetTileId: originTileId,\n    originTileId: targetTileId,\n    type: 'troopMovementReturn',\n    originalMovementType: 'troopMovementRaid',\n  });",
        """  const { villageId, resolvesAt, troops, originTileId, targetTileId } = args;
  const carriedResources = raidVillageResources(
    database,
    targetTileId,
    resolvesAt,
    calculateRaidCarryCapacity(troops),
  );

  // TODO: Combat. LAN Arcade currently implements non-lethal raid loot so raids
  // are rewarding while upstream combat/report systems are still incomplete.
  createEvents<'troopMovementReturn'>(database, {
    villageId,
    troops,
    startsAt: resolvesAt,
    targetTileId: originTileId,
    originTileId: targetTileId,
    type: 'troopMovementReturn',
    originalMovementType: 'troopMovementRaid',
    carriedResources,
  } as never);""",
        1,
    )
    if 'calculateRaidCarryCapacity' not in s or 'carriedResources' not in s:
        raise SystemExit('Failed to patch raid loot resolver')
    resolver.write_text(s)

report_model = root / 'packages/types/src/models/report.ts'
s = report_model.read_text()
if 'title: string;' not in s:
    s = s.replace(
        'export type Report = BaseReport;\n',
        """export type Report = BaseReport & {
  type: ReportType;
  title: string;
  body: string;
};
""",
        1,
    )
    if 'title: string;' not in s:
        raise SystemExit('Failed to expand report model')
    report_model.write_text(s)

report_controllers = root / 'packages/api/src/http/controllers/report-controllers.ts'
s = report_controllers.read_text()
if 'LAN Arcade derived raid reports' not in s:
    report_controllers.write_text("""import { z } from 'zod';
import type { DbFacade } from '@pillage-first/utils/facades/database';
import { createController } from '../controller';

const reportTagSchema = z.enum(['read', 'archived']);
const reportResponseSchema = z.strictObject({
  id: z.string(),
  tags: z.array(reportTagSchema),
  timestamp: z.number().int(),
  villageId: z.number().int(),
  type: z.enum([
    'attack',
    'raid',
    'defence',
    'scout-attack',
    'scout-defence',
    'adventure',
    'trade',
  ]),
  title: z.string(),
  body: z.string(),
});

const reportEventRowSchema = z.strictObject({
  id: z.number(),
  timestamp: z.number(),
  villageId: z.number().nullable(),
  meta: z.string().nullable(),
});

type ReportEventRow = z.infer<typeof reportEventRowSchema>;
type RaidResourceBundle = [number, number, number, number];
type EventMeta = Record<string, unknown>;

const raidReportId = (eventId: number) => `raid-${eventId}`;
const parseRaidReportEventId = (reportId: string) => {
  const match = /^raid-(\\d+)$/.exec(reportId);
  return match ? Number(match[1]) : null;
};

const parseEventMeta = (meta: string | null): EventMeta => {
  if (!meta) {
    return {};
  }

  try {
    const parsed = JSON.parse(meta);
    return parsed && typeof parsed === 'object' ? parsed : {};
  } catch {
    return {};
  }
};

const parseTags = (meta: EventMeta) => {
  if (!Array.isArray(meta.lanArcadeReportTags)) {
    return [];
  }

  return meta.lanArcadeReportTags.filter(
    (tag): tag is z.infer<typeof reportTagSchema> =>
      tag === 'read' || tag === 'archived',
  );
};

const parseCarriedResources = (value: unknown): RaidResourceBundle => {
  if (!Array.isArray(value)) {
    return [0, 0, 0, 0];
  }

  return [0, 1, 2, 3].map((index) => {
    const amount = Number(value[index]);
    return Number.isFinite(amount) ? Math.max(0, Math.floor(amount)) : 0;
  }) as RaidResourceBundle;
};

const formatLoot = ([wood, clay, iron, wheat]: RaidResourceBundle) => {
  return `${wood} wood, ${clay} clay, ${iron} iron, ${wheat} wheat`;
};

const mapRaidEventToReport = (row: ReportEventRow) => {
  const meta = parseEventMeta(row.meta);
  if (meta.originalMovementType !== 'troopMovementRaid') {
    return null;
  }

  const carriedResources = parseCarriedResources(meta.carriedResources);
  const total = carriedResources.reduce((sum, amount) => sum + amount, 0);

  return {
    id: raidReportId(row.id),
    tags: parseTags(meta),
    timestamp: row.timestamp,
    villageId: row.villageId ?? 0,
    type: 'raid' as const,
    title: total > 0 ? `Raid gained ${total} resources` : 'Raid returned empty',
    body:
      total > 0
        ? `Loot carried home: ${formatLoot(carriedResources)}.`
        : 'Your troops reached the target but found no resources to carry home.',
  };
};

const getDerivedRaidReports = (database: DbFacade) => {
  const rows = database.selectObjects({
    sql: `
      SELECT
        id,
        starts_at AS timestamp,
        village_id AS villageId,
        meta
      FROM
        events
      WHERE
        type = 'troopMovementReturn'
      ORDER BY
        starts_at DESC;
    `,
    schema: reportEventRowSchema,
  });

  return rows.flatMap((row) => {
    const report = mapRaidEventToReport(row);
    return report ? [report] : [];
  });
};

const tagDerivedRaidReport = (
  database: DbFacade,
  reportId: string,
  tag: z.infer<typeof reportTagSchema>,
) => {
  const eventId = parseRaidReportEventId(reportId);
  if (eventId === null) {
    return;
  }

  const row = database.selectObject({
    sql: "SELECT meta FROM events WHERE id = $event_id AND type = 'troopMovementReturn';",
    bind: { $event_id: eventId },
    schema: z.strictObject({ meta: z.string().nullable() }),
  });

  if (!row) {
    return;
  }

  const meta = parseEventMeta(row.meta);
  if (meta.originalMovementType !== 'troopMovementRaid') {
    return;
  }

  meta.lanArcadeReportTags = Array.from(new Set([...parseTags(meta), tag]));

  database.exec({
    sql: 'UPDATE events SET meta = $meta WHERE id = $event_id;',
    bind: { $event_id: eventId, $meta: JSON.stringify(meta) },
  });
};

export const getMyReports = createController('/players/:playerId/reports', {
  summary: 'Get my reports',
  requestParams: {
    path: z.strictObject({
      playerId: z.coerce.number(),
    }),
  },
  response: z.array(reportResponseSchema),
})(({ database }) => {
  // LAN Arcade derived raid reports: upstream reports are still incomplete.
  return getDerivedRaidReports(database);
});

export const getUnreadReportCount = createController(
  '/players/:playerId/reports/unread-count',
  {
    summary: 'Get unread reports count',
    requestParams: {
      path: z.strictObject({
        playerId: z.coerce.number(),
      }),
    },
    response: z.number().int(),
  },
)(({ database }) => {
  return getDerivedRaidReports(database).filter(
    (report) => !report.tags.includes('read') && !report.tags.includes('archived'),
  ).length;
});

export const updateReport = createController('/reports/:reportId', 'patch', {
  summary: 'Update report',
  requestParams: {
    path: z.strictObject({
      reportId: z.string(),
    }),
  },
  requestBody: z.strictObject({
    tag: reportTagSchema,
  }),
})(({ database, path: { reportId }, body: { tag } }) => {
  tagDerivedRaidReport(database, reportId, tag);
});

export const deleteReport = createController('/reports/:reportId', 'delete', {
  summary: 'Delete report',
  requestParams: {
    path: z.strictObject({
      reportId: z.string(),
    }),
  },
})(({ database, path: { reportId } }) => {
  tagDerivedRaidReport(database, reportId, 'archived');
});
""")

reports_components = root / 'apps/web/app/(game)/(village-slug)/(reports)/components'
report_list = reports_components / 'report-list.tsx'
report_list.write_text(r"""import { useTranslation } from 'react-i18next';
import type { Report } from '@pillage-first/types/models/report';
import { Text } from 'app/components/text';
import { Alert } from 'app/components/ui/alert';
import { Badge } from 'app/components/ui/badge';

type ReportListProps = {
  reports: Report[];
};

type ReportSummaryItem = {
  label: string;
  value: string;
  emphasis?: 'neutral' | 'good' | 'bad';
};

const reportFieldLabels = [
  'Attackers sent',
  'Attacker losses',
  'Attackers returned',
  'Defenders present',
  'Defender losses',
  'Defenders remaining',
  'Loot',
  'Outcome',
] as const;

const formatTimestamp = (timestamp: number) => {
  return new Intl.DateTimeFormat(undefined, {
    day: '2-digit',
    month: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(timestamp));
};

const formatTimestampTitle = (timestamp: number) => {
  return new Date(timestamp).toLocaleString();
};

const escapeRegExp = (value: string) => {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
};

const extractReportField = (body: string, label: string) => {
  const match = body.match(new RegExp(`${escapeRegExp(label)}:\\s*([^.]*)`, 'i'));
  return match?.[1]?.trim() ?? '';
};

const extractFirstReportField = (body: string, labels: string[]) => {
  for (const label of labels) {
    const value = extractReportField(body, label);

    if (value) {
      return value;
    }
  }

  return '';
};

const sentenceCase = (value: string) => {
  if (!value) {
    return value;
  }

  return value.charAt(0).toUpperCase() + value.slice(1);
};

const typeLabel = (type: Report['type']) => {
  return type.replaceAll('-', ' ');
};

const typeBadgeVariant = (type: Report['type']) => {
  if (type === 'attack' || type === 'defence') {
    return 'destructive' as const;
  }

  if (type === 'raid' || type === 'trade') {
    return 'secondary' as const;
  }

  return 'outline' as const;
};

const summarizeReport = (report: Report): ReportSummaryItem[] => {
  const body = report.body;
  const attackers = extractFirstReportField(body, [
    'Attackers sent',
    'Attackers returned',
  ]);
  const defenders = extractFirstReportField(body, [
    'Defenders present',
    'Defenders remaining',
  ]);
  const attackerLosses = extractReportField(body, 'Attacker losses');
  const defenderLosses = extractReportField(body, 'Defender losses');
  const loot = extractFirstReportField(body, ['Loot', 'Loot carried home']);
  const outcome = extractReportField(body, 'Outcome') || report.title;

  return [
    { label: 'Outcome', value: sentenceCase(outcome) },
    { label: 'Attackers', value: attackers },
    { label: 'Defenders', value: defenders },
    { label: 'Attacker losses', value: attackerLosses, emphasis: attackerLosses && attackerLosses !== 'none' ? 'bad' : 'good' },
    { label: 'Defender losses', value: defenderLosses },
    { label: 'Resources', value: loot },
  ].filter((item) => item.value) as ReportSummaryItem[];
};

const hasStructuredReportFields = (report: Report) => {
  return reportFieldLabels.some((label) => report.body.includes(`${label}:`));
};

const ReportSummaryGrid = ({ report }: { report: Report }) => {
  const { t } = useTranslation();
  const summary = summarizeReport(report);

  if (summary.length === 0) {
    return (
      <Text className="break-words text-sm text-muted-foreground">
        {report.body}
      </Text>
    );
  }

  return (
    <div className="grid gap-2 sm:grid-cols-2 xl:grid-cols-3">
      {summary.map((item) => (
        <div
          key={`${report.id}-${item.label}`}
          className="min-w-0 rounded-sm border border-border bg-background/60 p-2"
        >
          <div className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
            {t(item.label)}
          </div>
          <div
            className={`break-words text-sm ${
              item.emphasis === 'bad'
                ? 'text-destructive'
                : item.emphasis === 'good'
                  ? 'text-success'
                  : 'text-foreground'
            }`}
          >
            {item.value}
          </div>
        </div>
      ))}
    </div>
  );
};

export const ReportList = ({ reports }: ReportListProps) => {
  const { t } = useTranslation();

  if (reports.length === 0) {
    return <Alert variant="info">{t('No reports yet')}</Alert>;
  }

  return (
    <div className="grid w-full gap-3">
      {reports.map((report) => (
        <article
          key={report.id}
          className="w-full rounded-md border border-border bg-card/70 p-3 shadow-sm"
        >
          <div className="flex flex-col gap-2 sm:flex-row sm:items-start sm:justify-between">
            <div className="min-w-0 space-y-1">
              <div className="flex flex-wrap items-center gap-2">
                <Badge variant={typeBadgeVariant(report.type)}>
                  {t(sentenceCase(typeLabel(report.type)))}
                </Badge>
                <Badge variant="outline">
                  {report.tags.length > 0 ? report.tags.join(', ') : t('New')}
                </Badge>
                <span
                  className="text-sm text-muted-foreground"
                  title={formatTimestampTitle(report.timestamp)}
                >
                  {formatTimestamp(report.timestamp)}
                </span>
              </div>
              <Text
                as="h3"
                className="break-words text-base font-semibold"
              >
                {report.title}
              </Text>
            </div>
            <div className="shrink-0 text-sm text-muted-foreground">
              {t('Village')} #{report.villageId}
            </div>
          </div>

          <div className="mt-3">
            <ReportSummaryGrid report={report} />
          </div>

          {hasStructuredReportFields(report) ? (
            <details className="mt-3 rounded-sm border border-border bg-background/40 p-2 text-sm">
              <summary className="cursor-pointer font-medium text-muted-foreground">
                {t('Full report text')}
              </summary>
              <Text className="mt-2 break-words text-sm text-muted-foreground">
                {report.body}
              </Text>
            </details>
          ) : null}
        </article>
      ))}
    </div>
  );
};
""")

reports_page = reports_components / 'reports.tsx'
reports_page.write_text("""import { useMemo } from 'react';
import { useTranslation } from 'react-i18next';
import { ReportFilters } from 'app/(game)/(village-slug)/(reports)/components/components/report-filters';
import { ReportList } from 'app/(game)/(village-slug)/(reports)/components/report-list';
import { useReportFilters } from 'app/(game)/(village-slug)/(reports)/hooks/use-report-filters';
import {
  Section,
  SectionContent,
} from 'app/(game)/(village-slug)/components/building-layout';
import { usePagination } from 'app/(game)/(village-slug)/hooks/use-pagination';
import { useReports } from 'app/(game)/(village-slug)/hooks/use-reports';
import { Text } from 'app/components/text';
import { Pagination } from 'app/components/ui/pagination';

export const Reports = () => {
  const { t } = useTranslation();
  const { reports } = useReports();
  const {
    filters: reportFilters,
    onFiltersChange: onReportFiltersChange,
    page,
    handlePageChange,
  } = useReportFilters();

  const filteredReports = useMemo(() => {
    return reports.filter(
      (report) =>
        reportFilters.includes(report.type) && !report.tags.includes('archived'),
    );
  }, [reportFilters, reports]);

  const pagination = usePagination(filteredReports, 12, page);

  return (
    <Section>
      <SectionContent>
        <Text as="h2">{t('All reports')}</Text>
        <Text>
          {t(
            'This is a categorized view of in-game reports. You can toggle different types of reports by using report filters below.',
          )}
        </Text>
      </SectionContent>
      <ReportFilters
        reportFilters={reportFilters}
        onChange={onReportFiltersChange}
      />
      <Text className="text-sm text-muted-foreground">
        {t('Showing {{start}}-{{end}} of {{count}} reports', {
          start:
            filteredReports.length === 0
              ? 0
              : (pagination.page - 1) * pagination.resultsPerPage + 1,
          end: Math.min(
            filteredReports.length,
            pagination.page * pagination.resultsPerPage,
          ),
          count: filteredReports.length,
        })}
      </Text>
      <ReportList reports={pagination.currentPageItems} />
      <div className="flex w-full justify-end">
        <Pagination
          {...pagination}
          setPage={handlePageChange}
        />
      </div>
    </Section>
  );
};
""")

current_reports_page = reports_components / 'current-village-reports.tsx'
current_reports_page.write_text("""import { useMemo } from 'react';
import { useTranslation } from 'react-i18next';
import { ReportFilters } from 'app/(game)/(village-slug)/(reports)/components/components/report-filters';
import { ReportList } from 'app/(game)/(village-slug)/(reports)/components/report-list';
import { useReportFilters } from 'app/(game)/(village-slug)/(reports)/hooks/use-report-filters';
import {
  Section,
  SectionContent,
} from 'app/(game)/(village-slug)/components/building-layout';
import { useCurrentVillage } from 'app/(game)/(village-slug)/hooks/current-village/use-current-village';
import { usePagination } from 'app/(game)/(village-slug)/hooks/use-pagination';
import { useReports } from 'app/(game)/(village-slug)/hooks/use-reports';
import { Text } from 'app/components/text';
import { Pagination } from 'app/components/ui/pagination';

export const CurrentVillageReports = () => {
  const { t } = useTranslation();
  const { reports } = useReports();
  const { currentVillage } = useCurrentVillage();
  const {
    filters: reportFilters,
    onFiltersChange: onReportFiltersChange,
    page,
    handlePageChange,
  } = useReportFilters();

  const filteredReports = useMemo(() => {
    return reports.filter(
      (report) =>
        report.villageId === currentVillage.id &&
        reportFilters.includes(report.type) &&
        !report.tags.includes('archived'),
    );
  }, [currentVillage.id, reportFilters, reports]);

  const pagination = usePagination(filteredReports, 12, page);

  return (
    <Section>
      <SectionContent>
        <Text as="h2">{t('Current village reports')}</Text>
        <Text>
          {t(
            'This is a categorized view of in-game reports for current village. You can toggle different types of reports by using report filters below.',
          )}
        </Text>
      </SectionContent>
      <ReportFilters
        reportFilters={reportFilters}
        onChange={onReportFiltersChange}
      />
      <Text className="text-sm text-muted-foreground">
        {t('Showing {{start}}-{{end}} of {{count}} reports', {
          start:
            filteredReports.length === 0
              ? 0
              : (pagination.page - 1) * pagination.resultsPerPage + 1,
          end: Math.min(
            filteredReports.length,
            pagination.page * pagination.resultsPerPage,
          ),
          count: filteredReports.length,
        })}
      </Text>
      <ReportList reports={pagination.currentPageItems} />
      <div className="flex w-full justify-end">
        <Pagination
          {...pagination}
          setPage={handlePageChange}
        />
      </div>
    </Section>
  );
};
""")

archived_reports_page = reports_components / 'archived-reports.tsx'
archived_reports_page.write_text("""import { useMemo } from 'react';
import { useTranslation } from 'react-i18next';
import { ReportFilters } from 'app/(game)/(village-slug)/(reports)/components/components/report-filters';
import { ReportList } from 'app/(game)/(village-slug)/(reports)/components/report-list';
import { useReportFilters } from 'app/(game)/(village-slug)/(reports)/hooks/use-report-filters';
import {
  Section,
  SectionContent,
} from 'app/(game)/(village-slug)/components/building-layout';
import { usePagination } from 'app/(game)/(village-slug)/hooks/use-pagination';
import { useReports } from 'app/(game)/(village-slug)/hooks/use-reports';
import { Text } from 'app/components/text';
import { Pagination } from 'app/components/ui/pagination';

export const ArchivedReports = () => {
  const { t } = useTranslation();
  const { reports } = useReports();
  const {
    filters: reportFilters,
    onFiltersChange: onReportFiltersChange,
    page,
    handlePageChange,
  } = useReportFilters();

  const filteredReports = useMemo(() => {
    return reports.filter(
      (report) =>
        reportFilters.includes(report.type) && report.tags.includes('archived'),
    );
  }, [reportFilters, reports]);

  const pagination = usePagination(filteredReports, 12, page);

  return (
    <Section>
      <SectionContent>
        <Text as="h2">{t('Archived reports')}</Text>
        <Text>
          {t(
            'This is a categorized view of archived reports. These reports are not deleted once a limit is reached and you can have an unlimited amount of them. You can toggle different types of reports by using report filters below.',
          )}
        </Text>
      </SectionContent>
      <ReportFilters
        reportFilters={reportFilters}
        onChange={onReportFiltersChange}
      />
      <Text className="text-sm text-muted-foreground">
        {t('Showing {{start}}-{{end}} of {{count}} reports', {
          start:
            filteredReports.length === 0
              ? 0
              : (pagination.page - 1) * pagination.resultsPerPage + 1,
          end: Math.min(
            filteredReports.length,
            pagination.page * pagination.resultsPerPage,
          ),
          count: filteredReports.length,
        })}
      </Text>
      <ReportList reports={pagination.currentPageItems} />
      <div className="flex w-full justify-end">
        <Pagination
          {...pagination}
          setPage={handlePageChange}
        />
      </div>
    </Section>
  );
};
""")


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


python3 - <<'PY'
from pathlib import Path
root = Path('.')

# LAN Arcade persistent reports and conservative raid defence patch.
# Keep this separate from the upstream compatibility patch above so rebuilds
# cannot lose player reports after troop return events are resolved/deleted.
report_controllers = root / 'packages/api/src/http/controllers/report-controllers.ts'
report_controllers.write_text(r"""import { z } from 'zod';
import type { DbFacade } from '@pillage-first/utils/facades/database';
import { createController } from '../controller';

const reportTagSchema = z.enum(['read', 'archived']);
const reportTypeSchema = z.enum([
  'attack',
  'raid',
  'defence',
  'scout-attack',
  'scout-defence',
  'adventure',
  'trade',
]);
const reportResponseSchema = z.strictObject({
  id: z.string(),
  tags: z.array(reportTagSchema),
  timestamp: z.number().int(),
  villageId: z.number().int(),
  type: reportTypeSchema,
  title: z.string(),
  body: z.string(),
});

const reportRowSchema = z.strictObject({
  id: z.string(),
  playerId: z.number(),
  villageId: z.number(),
  timestamp: z.number(),
  type: reportTypeSchema,
  title: z.string(),
  body: z.string(),
  tags: z.string(),
});

const reportEventRowSchema = z.strictObject({
  id: z.number(),
  timestamp: z.number(),
  villageId: z.number().nullable(),
  meta: z.string().nullable(),
});

type ReportEventRow = z.infer<typeof reportEventRowSchema>;
type ReportTag = z.infer<typeof reportTagSchema>;
type RaidResourceBundle = [number, number, number, number];
type EventMeta = Record<string, unknown>;

const ensureLanArcadeReportsTable = (database: DbFacade) => {
  database.exec({
    sql: `
      CREATE TABLE IF NOT EXISTS lan_arcade_reports
      (
        id TEXT PRIMARY KEY,
        player_id INTEGER NOT NULL,
        village_id INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        type TEXT NOT NULL CHECK (type IN ('attack', 'raid', 'defence', 'scout-attack', 'scout-defence', 'adventure', 'trade')),
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        tags TEXT NOT NULL
      ) STRICT;
    `,
  });
};

const parseEventMeta = (meta: string | null): EventMeta => {
  if (!meta) {
    return {};
  }

  try {
    const parsed = JSON.parse(meta);
    return parsed && typeof parsed === 'object' ? parsed : {};
  } catch {
    return {};
  }
};

const parseReportTags = (value: unknown): ReportTag[] => {
  if (typeof value === 'string') {
    try {
      return parseReportTags(JSON.parse(value));
    } catch {
      return [];
    }
  }

  if (!Array.isArray(value)) {
    return [];
  }

  return value.filter(
    (tag): tag is ReportTag => tag === 'read' || tag === 'archived',
  );
};

const parseCarriedResources = (value: unknown): RaidResourceBundle => {
  if (!Array.isArray(value)) {
    return [0, 0, 0, 0];
  }

  return [0, 1, 2, 3].map((index) => {
    const amount = Number(value[index]);
    return Number.isFinite(amount) ? Math.max(0, Math.floor(amount)) : 0;
  }) as RaidResourceBundle;
};

const formatLoot = ([wood, clay, iron, wheat]: RaidResourceBundle) => {
  return `${wood} wood, ${clay} clay, ${iron} iron, ${wheat} wheat`;
};

const mapReportRow = (row: z.infer<typeof reportRowSchema>) => {
  return reportResponseSchema.parse({
    id: row.id,
    tags: parseReportTags(row.tags),
    timestamp: row.timestamp,
    villageId: row.villageId,
    type: row.type,
    title: row.title,
    body: row.body,
  });
};

const raidReportId = (eventId: number) => `raid-${eventId}`;
const legacyRaidReturnReportId = (eventId: number) => `raid-return-${eventId}`;

const mapRaidEventToReport = (row: ReportEventRow) => {
  const meta = parseEventMeta(row.meta);
  if (meta.originalMovementType !== 'troopMovementRaid') {
    return null;
  }

  const originalMovementEventId = Number(meta.originalMovementEventId);
  const id = Number.isFinite(originalMovementEventId)
    ? raidReportId(originalMovementEventId)
    : legacyRaidReturnReportId(row.id);
  const carriedResources = parseCarriedResources(meta.carriedResources);
  const defenderCount = Number(meta.defenderCount ?? 0);
  const total = carriedResources.reduce((sum, amount) => sum + amount, 0);
  const wasBlocked = Number.isFinite(defenderCount) && defenderCount > 0;

  return {
    id,
    tags: parseReportTags(meta.lanArcadeReportTags),
    timestamp: row.timestamp,
    villageId: row.villageId ?? 0,
    type: 'raid' as const,
    title: wasBlocked
      ? `Raid blocked by ${Math.floor(defenderCount)} defenders`
      : total > 0
        ? `Raid gained ${total} resources`
        : 'Raid returned empty',
    body: wasBlocked
      ? 'Your troops found defenders and returned without loot. Full casualty combat is still disabled in this LAN build.'
      : total > 0
        ? `Loot carried home: ${formatLoot(carriedResources)}.`
        : 'Your troops reached the target but found no resources to carry home.',
  };
};

const persistDerivedRaidReports = (database: DbFacade, playerId: number) => {
  const rows = database.selectObjects({
    sql: `
      SELECT
        id,
        starts_at AS timestamp,
        village_id AS villageId,
        meta
      FROM
        events
      WHERE
        type = 'troopMovementReturn'
      ORDER BY
        starts_at DESC;
    `,
    schema: reportEventRowSchema,
  });

  const stmt = database.prepare({
    sql: `
      INSERT OR IGNORE INTO lan_arcade_reports
        (id, player_id, village_id, timestamp, type, title, body, tags)
      VALUES
        ($id, $player_id, $village_id, $timestamp, $type, $title, $body, $tags);
    `,
  });

  for (const row of rows) {
    const report = mapRaidEventToReport(row);
    if (!report) {
      continue;
    }

    stmt
      .bind({
        $id: report.id,
        $player_id: playerId,
        $village_id: report.villageId,
        $timestamp: report.timestamp,
        $type: report.type,
        $title: report.title,
        $body: report.body,
        $tags: JSON.stringify(report.tags),
      })
      .stepReset();
  }
};

const getReports = (database: DbFacade, playerId: number) => {
  ensureLanArcadeReportsTable(database);
  persistDerivedRaidReports(database, playerId);

  const rows = database.selectObjects({
    sql: `
      SELECT
        id,
        player_id AS playerId,
        village_id AS villageId,
        timestamp,
        type,
        title,
        body,
        tags
      FROM
        lan_arcade_reports
      WHERE
        player_id = $player_id
      ORDER BY
        timestamp DESC,
        id DESC;
    `,
    bind: { $player_id: playerId },
    schema: reportRowSchema,
  });

  return rows.map(mapReportRow);
};

const tagPersistentReport = (
  database: DbFacade,
  reportId: string,
  tag: ReportTag,
) => {
  ensureLanArcadeReportsTable(database);

  const row = database.selectObject({
    sql: 'SELECT tags FROM lan_arcade_reports WHERE id = $report_id;',
    bind: { $report_id: reportId },
    schema: z.strictObject({ tags: z.string() }),
  });

  if (!row) {
    return;
  }

  const tags = Array.from(new Set([...parseReportTags(row.tags), tag]));

  database.exec({
    sql: 'UPDATE lan_arcade_reports SET tags = $tags WHERE id = $report_id;',
    bind: { $report_id: reportId, $tags: JSON.stringify(tags) },
  });
};

export const getMyReports = createController('/players/:playerId/reports', {
  summary: 'Get my reports',
  requestParams: {
    path: z.strictObject({
      playerId: z.coerce.number(),
    }),
  },
  response: z.array(reportResponseSchema),
})(({ database, path: { playerId } }) => {
  // LAN Arcade persistent raid reports: reports survive troop return cleanup.
  return getReports(database, playerId);
});

export const getUnreadReportCount = createController(
  '/players/:playerId/reports/unread-count',
  {
    summary: 'Get unread reports count',
    requestParams: {
      path: z.strictObject({
        playerId: z.coerce.number(),
      }),
    },
    response: z.number().int(),
  },
)(({ database, path: { playerId } }) => {
  return getReports(database, playerId).filter(
    (report) => !report.tags.includes('read') && !report.tags.includes('archived'),
  ).length;
});

export const updateReport = createController('/reports/:reportId', 'patch', {
  summary: 'Update report',
  requestParams: {
    path: z.strictObject({
      reportId: z.string(),
    }),
  },
  requestBody: z.strictObject({
    tag: reportTagSchema,
  }),
})(({ database, path: { reportId }, body: { tag } }) => {
  tagPersistentReport(database, reportId, tag);
});

export const deleteReport = createController('/reports/:reportId', 'delete', {
  summary: 'Delete report',
  requestParams: {
    path: z.strictObject({
      reportId: z.string(),
    }),
  },
})(({ database, path: { reportId } }) => {
  tagPersistentReport(database, reportId, 'archived');
});
""")

resolver = root / 'packages/api/src/http/events/resolvers/troop-movement-resolver.ts'
s = resolver.read_text()
if 'LAN_ARCADE_REPORT_TABLE_PATCH' not in s:
    target = """const raidTargetResourcesSchema = z.strictObject({
  villageId: z.number(),
  wood: z.number(),
  clay: z.number(),
  iron: z.number(),
  wheat: z.number(),
});

"""
    replacement = target + r"""// LAN_ARCADE_REPORT_TABLE_PATCH
const ensureLanArcadeReportsTable = (
  database: Parameters<Resolver<GameEvent<'troopMovementRaid'>>>[0],
) => {
  database.exec({
    sql: `
      CREATE TABLE IF NOT EXISTS lan_arcade_reports
      (
        id TEXT PRIMARY KEY,
        player_id INTEGER NOT NULL,
        village_id INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        type TEXT NOT NULL CHECK (type IN ('attack', 'raid', 'defence', 'scout-attack', 'scout-defence', 'adventure', 'trade')),
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        tags TEXT NOT NULL
      ) STRICT;
    `,
  });
};

const formatRaidLoot = ([wood, clay, iron, wheat]: RaidResourceBundle) => {
  return `${wood} wood, ${clay} clay, ${iron} iron, ${wheat} wheat`;
};

const insertLanArcadeReport = (
  database: Parameters<Resolver<GameEvent<'troopMovementRaid'>>>[0],
  report: {
    id: string;
    villageId: number;
    timestamp: number;
    type: 'attack' | 'raid';
    title: string;
    body: string;
  },
) => {
  ensureLanArcadeReportsTable(database);

  database.exec({
    sql: `
      INSERT OR REPLACE INTO lan_arcade_reports
        (id, player_id, village_id, timestamp, type, title, body, tags)
      VALUES
        ($id, $player_id, $village_id, $timestamp, $type, $title, $body,
         COALESCE((SELECT tags FROM lan_arcade_reports WHERE id = $id), '[]'));
    `,
    bind: {
      $id: report.id,
      $player_id: PLAYER_ID,
      $village_id: report.villageId,
      $timestamp: report.timestamp,
      $type: report.type,
      $title: report.title,
      $body: report.body,
    },
  });
};

const countDefendersAtTile = (
  database: Parameters<Resolver<GameEvent<'troopMovementRaid'>>>[0],
  targetTileId: number,
) => {
  return database.selectValue({
    sql: `
      SELECT
        COALESCE(SUM(amount), 0) AS defender_count
      FROM
        troops
      WHERE
        tile_id = $target_tile_id;
    `,
    bind: { $target_tile_id: targetTileId },
    schema: z.number(),
  }) ?? 0;
};

const createLanArcadeRaidReport = (
  database: Parameters<Resolver<GameEvent<'troopMovementRaid'>>>[0],
  args: {
    eventId: number;
    villageId: number;
    timestamp: number;
    carriedResources: RaidResourceBundle;
    defenderCount: number;
  },
) => {
  const total = args.carriedResources.reduce((sum, amount) => sum + amount, 0);

  insertLanArcadeReport(database, {
    id: `raid-${args.eventId}`,
    villageId: args.villageId,
    timestamp: args.timestamp,
    type: 'raid',
    title:
      args.defenderCount > 0
        ? `Raid blocked by ${args.defenderCount} defenders`
        : total > 0
          ? `Raid gained ${total} resources`
          : 'Raid returned empty',
    body:
      args.defenderCount > 0
        ? 'Your troops found defenders and returned without loot. Full casualty combat is still disabled in this LAN build.'
        : total > 0
          ? `Loot carried home: ${formatRaidLoot(args.carriedResources)}.`
          : 'Your troops reached the target but found no resources to carry home.',
  });
};

const createLanArcadeAttackReport = (
  database: Parameters<Resolver<GameEvent<'troopMovementAttack'>>>[0],
  args: {
    eventId: number;
    villageId: number;
    timestamp: number;
    defenderCount: number;
  },
) => {
  insertLanArcadeReport(database, {
    id: `attack-${args.eventId}`,
    villageId: args.villageId,
    timestamp: args.timestamp,
    type: 'attack',
    title:
      args.defenderCount > 0
        ? `Attack met ${args.defenderCount} defenders`
        : 'Attack reached an undefended target',
    body:
      args.defenderCount > 0
        ? 'Your troops found defenders and returned without casualties. Full attack combat is still disabled in this LAN build.'
        : 'Your troops reached the target and returned. Full attack combat is still disabled in this LAN build.',
  });
};

"""
    if target not in s:
        raise SystemExit('Failed to find raid target schema insertion point')
    s = s.replace(target, replacement, 1)

old_attack = """export const attackMovementResolver: Resolver<
  GameEvent<'troopMovementAttack'>
> = (database, args) => {
  const { villageId, resolvesAt, originTileId, targetTileId, troops } = args;

  // TODO: Combat
  createEvents<'troopMovementReturn'>(database, {
    villageId,
    troops,
    targetTileId: originTileId,
    originTileId: targetTileId,
    startsAt: resolvesAt,
    type: 'troopMovementReturn',
    originalMovementType: 'troopMovementAttack',
  });

  const targetVillageIds = database.selectValues({
    sql: selectPlayerVillageIdByTileIdQuery,
    bind: { $tile_id: targetTileId, $player_id: PLAYER_ID },
    schema: z.number(),
  });

  return {
    affectedVillageIds: [villageId, ...targetVillageIds],
  };
};
"""
new_attack = """export const attackMovementResolver: Resolver<
  GameEvent<'troopMovementAttack'>
> = (database, args) => {
  const { id, villageId, resolvesAt, originTileId, targetTileId, troops } = args;
  const defenderCount = countDefendersAtTile(database, targetTileId);

  // LAN Arcade: make incomplete combat visible instead of silently bypassing it.
  createLanArcadeAttackReport(database, {
    eventId: id,
    villageId,
    timestamp: resolvesAt,
    defenderCount,
  });

  createEvents<'troopMovementReturn'>(database, {
    villageId,
    troops,
    targetTileId: originTileId,
    originTileId: targetTileId,
    startsAt: resolvesAt,
    type: 'troopMovementReturn',
    originalMovementType: 'troopMovementAttack',
    originalMovementEventId: id,
    defenderCount,
  } as never);

  const targetVillageIds = database.selectValues({
    sql: selectPlayerVillageIdByTileIdQuery,
    bind: { $tile_id: targetTileId, $player_id: PLAYER_ID },
    schema: z.number(),
  });

  return {
    affectedVillageIds: [villageId, ...targetVillageIds],
  };
};
"""
if old_attack not in s:
    raise SystemExit('Failed to find attack resolver block')
s = s.replace(old_attack, new_attack, 1)

old_raid = """export const raidMovementResolver: Resolver<GameEvent<'troopMovementRaid'>> = (
  database,
  args,
) => {
  const { villageId, resolvesAt, troops, originTileId, targetTileId } = args;
  const carriedResources = raidVillageResources(
    database,
    targetTileId,
    resolvesAt,
    calculateRaidCarryCapacity(troops),
  );

  // TODO: Combat. LAN Arcade currently implements non-lethal raid loot so raids
  // are rewarding while upstream combat/report systems are still incomplete.
  createEvents<'troopMovementReturn'>(database, {
    villageId,
    troops,
    startsAt: resolvesAt,
    targetTileId: originTileId,
    originTileId: targetTileId,
    type: 'troopMovementReturn',
    originalMovementType: 'troopMovementRaid',
    carriedResources,
  } as never);

  const targetVillageIds = database.selectValues({
    sql: selectPlayerVillageIdByTileIdQuery,
    bind: { $tile_id: targetTileId, $player_id: PLAYER_ID },
    schema: z.number(),
  });

  return {
    affectedVillageIds: [villageId, ...targetVillageIds],
  };
};
"""
new_raid = """export const raidMovementResolver: Resolver<GameEvent<'troopMovementRaid'>> = (
  database,
  args,
) => {
  const { id, villageId, resolvesAt, troops, originTileId, targetTileId } = args;
  const defenderCount = countDefendersAtTile(database, targetTileId);
  const carriedResources =
    defenderCount > 0
      ? emptyRaidResourceBundle()
      : raidVillageResources(
          database,
          targetTileId,
          resolvesAt,
          calculateRaidCarryCapacity(troops),
        );

  // LAN Arcade: defended raids return empty until full casualty combat exists.
  createLanArcadeRaidReport(database, {
    eventId: id,
    villageId,
    timestamp: resolvesAt,
    carriedResources,
    defenderCount,
  });

  createEvents<'troopMovementReturn'>(database, {
    villageId,
    troops,
    startsAt: resolvesAt,
    targetTileId: originTileId,
    originTileId: targetTileId,
    type: 'troopMovementReturn',
    originalMovementType: 'troopMovementRaid',
    originalMovementEventId: id,
    carriedResources,
    defenderCount,
  } as never);

  const targetVillageIds = database.selectValues({
    sql: selectPlayerVillageIdByTileIdQuery,
    bind: { $tile_id: targetTileId, $player_id: PLAYER_ID },
    schema: z.number(),
  });

  return {
    affectedVillageIds: [villageId, ...targetVillageIds],
  };
};
"""
if old_raid not in s:
    raise SystemExit('Failed to find raid resolver block')
s = s.replace(old_raid, new_raid, 1)
resolver.write_text(s)
PY


python3 - <<'PY'
from pathlib import Path
root = Path('.')


report_controllers = root / 'packages/api/src/http/controllers/report-controllers.ts'
rc = report_controllers.read_text()
rc = rc.replace(
    'Your troops found defenders and returned without loot. Full casualty combat is still disabled in this LAN build.',
    'Legacy raid report: defenders stopped this raid before raid combat was implemented. New raids now resolve casualties and survivor loot.',
)
ensure_tail = """  });
};

const parseEventMeta"""
ensure_replacement = """  });

  // LAN Arcade legacy report text migration: existing browser saves may contain
  // the previous stopgap wording even after the combat resolver is upgraded.
  database.exec({
    sql: `
      UPDATE lan_arcade_reports
      SET body = REPLACE(
        REPLACE(
          body,
          'Your troops found defenders and returned without loot. Full casualty combat is still disabled in this LAN build.',
          'Legacy raid report: defenders stopped this raid before raid combat was implemented. New raids now resolve casualties and survivor loot.'
        ),
        'Your troops found defenders and returned without casualties. Full attack combat is still disabled in this LAN build.',
        'Legacy attack report: this attack was recorded before attack combat reporting was implemented. New attacks now resolve casualties.'
      )
      WHERE
        body LIKE '%Full casualty combat is still disabled%'
        OR body LIKE '%Full attack combat is still disabled%';
    `,
  });
};

const parseEventMeta"""
if ensure_tail not in rc:
    raise SystemExit('Failed to find report table ensure tail for legacy text migration')
rc = rc.replace(ensure_tail, ensure_replacement, 1)
report_controllers.write_text(rc)

# LAN Arcade raid combat patch.
# Adds small Travian-like raid/attack casualty handling on top of the persistent
# report patch without refactoring the upstream event system.
resolver = root / 'packages/api/src/http/events/resolvers/troop-movement-resolver.ts'
s = resolver.read_text()
s = s.replace(
    "import type { GameEvent } from '@pillage-first/types/models/game-event';\n",
    "import type { GameEvent } from '@pillage-first/types/models/game-event';\nimport { unitIdSchema } from '@pillage-first/types/models/unit';\n",
    1,
)
s = s.replace(
    "import { addTroops } from '../../../utils/troops';\n",
    "import { addTroops, removeTroops } from '../../../utils/troops';\n",
    1,
)
helper_start = s.index('const countDefendersAtTile = (')
helper_end = s.index('const calculateRaidCarryCapacity', helper_start)
combat_helpers = r"""type CombatTroop = GameEvent<'troopMovementRaid'>['troops'][number];
type CombatMode = 'attack' | 'raid';

type CombatResult = {
  attackPower: number;
  defencePower: number;
  attackerLosses: CombatTroop[];
  attackerSurvivors: CombatTroop[];
  defenderLosses: CombatTroop[];
  defenderSurvivors: CombatTroop[];
};

const combatTroopRowSchema = z.strictObject({
  unitId: unitIdSchema,
  amount: z.number(),
  tileId: z.number(),
  source: z.number(),
});

const selectDefendersAtTile = (
  database: Parameters<Resolver<GameEvent<'troopMovementRaid'>>>[0],
  targetTileId: number,
): CombatTroop[] => {
  return database.selectObjects({
    sql: `
      SELECT
        ui.unit AS unitId,
        t.amount,
        t.tile_id AS tileId,
        t.source_tile_id AS source
      FROM
        troops t
          JOIN unit_ids ui ON ui.id = t.unit_id
      WHERE
        t.tile_id = $target_tile_id
        AND t.amount > 0;
    `,
    bind: { $target_tile_id: targetTileId },
    schema: combatTroopRowSchema,
  });
};

const totalTroopCount = (troops: CombatTroop[]) => {
  return troops.reduce((sum, troop) => sum + troop.amount, 0);
};

const summarizeTroops = (troops: CombatTroop[]) => {
  if (troops.length === 0) {
    return 'none';
  }

  return troops
    .map(({ amount, unitId }) => `${amount} ${unitId.replaceAll('_', ' ')}`)
    .join(', ');
};

const calculateAttackPower = (troops: CombatTroop[]) => {
  return troops.reduce((total, { amount, unitId }) => {
    return total + amount * getUnitDefinition(unitId).attack;
  }, 0);
};

const calculateDefencePower = (
  defenders: CombatTroop[],
  attackers: CombatTroop[],
) => {
  const infantryAttackPower = attackers.reduce((total, { amount, unitId }) => {
    const unit = getUnitDefinition(unitId);
    return unit.category === 'cavalry' ? total : total + amount * unit.attack;
  }, 0);
  const cavalryAttackPower = attackers.reduce((total, { amount, unitId }) => {
    const unit = getUnitDefinition(unitId);
    return unit.category === 'cavalry' ? total + amount * unit.attack : total;
  }, 0);
  const totalAttackPower = infantryAttackPower + cavalryAttackPower;
  const infantryWeight = totalAttackPower > 0 ? infantryAttackPower / totalAttackPower : 0.5;
  const cavalryWeight = totalAttackPower > 0 ? cavalryAttackPower / totalAttackPower : 0.5;

  return defenders.reduce((total, { amount, unitId }) => {
    const unit = getUnitDefinition(unitId);
    const weightedDefence =
      unit.infantryDefence * infantryWeight + unit.cavalryDefence * cavalryWeight;
    return total + amount * weightedDefence;
  }, 0);
};

const splitTroopsByLossRatio = (
  troops: CombatTroop[],
  lossRatio: number,
) => {
  const total = totalTroopCount(troops);
  const clampedRatio = Math.max(0, Math.min(1, lossRatio));
  const targetLosses =
    clampedRatio <= 0 || total === 0
      ? 0
      : clampedRatio >= 1
        ? total
        : Math.max(1, Math.min(total, Math.round(total * clampedRatio)));

  const allocations = troops.map((troop) => {
    const rawLoss = troop.amount * clampedRatio;
    return {
      troop,
      loss: Math.min(troop.amount, Math.floor(rawLoss)),
      remainder: rawLoss - Math.floor(rawLoss),
    };
  });

  let allocated = allocations.reduce((sum, row) => sum + row.loss, 0);
  const ordered = [...allocations].sort((a, b) => b.remainder - a.remainder);

  while (allocated < targetLosses) {
    const row = ordered.find((candidate) => candidate.loss < candidate.troop.amount);
    if (!row) {
      break;
    }
    row.loss += 1;
    allocated += 1;
  }

  const losses = allocations
    .filter(({ loss }) => loss > 0)
    .map(({ troop, loss }) => ({ ...troop, amount: loss }));
  const survivors = allocations
    .filter(({ troop, loss }) => troop.amount - loss > 0)
    .map(({ troop, loss }) => ({ ...troop, amount: troop.amount - loss }));

  return { losses, survivors };
};

const resolveLanArcadeCombat = (
  mode: CombatMode,
  attackers: CombatTroop[],
  defenders: CombatTroop[],
): CombatResult => {
  const attackPower = calculateAttackPower(attackers);
  const defencePower = calculateDefencePower(defenders, attackers);
  let attackerLossRatio = 0;
  let defenderLossRatio = 0;

  if (attackers.length === 0) {
    attackerLossRatio = 0;
    defenderLossRatio = 0;
  } else if (defenders.length === 0 || defencePower <= 0) {
    attackerLossRatio = 0;
    defenderLossRatio = defenders.length > 0 && attackPower > 0 ? 1 : 0;
  } else if (attackPower <= 0) {
    attackerLossRatio = 1;
    defenderLossRatio = 0;
  } else if (mode === 'attack') {
    if (attackPower >= defencePower) {
      attackerLossRatio = Math.min(0.95, (defencePower / attackPower) * 0.7);
      defenderLossRatio = 1;
    } else {
      attackerLossRatio = 1;
      defenderLossRatio = Math.min(0.95, (attackPower / defencePower) * 0.7);
    }
  } else {
    const combinedPower = attackPower + defencePower;
    attackerLossRatio = defencePower / combinedPower;
    defenderLossRatio = attackPower / combinedPower;

    if (attackPower < defencePower * 0.35) {
      attackerLossRatio = 1;
    }
    if (defencePower < attackPower * 0.2) {
      defenderLossRatio = 1;
    }
  }

  const attackerResult = splitTroopsByLossRatio(attackers, attackerLossRatio);
  const defenderResult = splitTroopsByLossRatio(defenders, defenderLossRatio);

  return {
    attackPower,
    defencePower,
    attackerLosses: attackerResult.losses,
    attackerSurvivors: attackerResult.survivors,
    defenderLosses: defenderResult.losses,
    defenderSurvivors: defenderResult.survivors,
  };
};

const removeCombatLosses = (
  database: Parameters<Resolver<GameEvent<'troopMovementRaid'>>>[0],
  losses: CombatTroop[],
) => {
  if (losses.length > 0) {
    removeTroops(database, losses);
  }
};

const describeCombatReport = (args: {
  sentAttackers: CombatTroop[];
  defenders: CombatTroop[];
  combat: CombatResult;
  loot?: RaidResourceBundle;
}) => {
  const attackerLossCount = totalTroopCount(args.combat.attackerLosses);
  const defenderLossCount = totalTroopCount(args.combat.defenderLosses);
  const attackerSurvivorCount = totalTroopCount(args.combat.attackerSurvivors);
  const defenderSurvivorCount = totalTroopCount(args.combat.defenderSurvivors);
  const parts = [
    `Attackers sent: ${summarizeTroops(args.sentAttackers)}.`,
    `Attacker losses: ${summarizeTroops(args.combat.attackerLosses)}.`,
    `Attackers returned: ${summarizeTroops(args.combat.attackerSurvivors)}.`,
    `Defenders present: ${summarizeTroops(args.defenders)}.`,
    `Defender losses: ${summarizeTroops(args.combat.defenderLosses)}.`,
    `Defenders remaining: ${summarizeTroops(args.combat.defenderSurvivors)}.`,
  ];

  if (args.loot) {
    parts.push(`Loot: ${formatRaidLoot(args.loot)}.`);
  }

  parts.push(
    `Outcome: ${
      attackerSurvivorCount === 0
        ? 'attackers were wiped out'
        : defenderSurvivorCount === 0 && args.defenders.length > 0
          ? 'defenders were cleared'
          : attackerLossCount > 0 || defenderLossCount > 0
            ? 'both sides took losses'
            : 'no resistance'
    }.`
  );

  return parts.join(' ');
};

const createLanArcadeRaidReport = (
  database: Parameters<Resolver<GameEvent<'troopMovementRaid'>>>[0],
  args: {
    eventId: number;
    villageId: number;
    timestamp: number;
    sentAttackers: CombatTroop[];
    defenders: CombatTroop[];
    combat: CombatResult;
    carriedResources: RaidResourceBundle;
  },
) => {
  const total = args.carriedResources.reduce((sum, amount) => sum + amount, 0);
  const attackerLossCount = totalTroopCount(args.combat.attackerLosses);
  const survivorCount = totalTroopCount(args.combat.attackerSurvivors);

  insertLanArcadeReport(database, {
    id: `raid-${args.eventId}`,
    villageId: args.villageId,
    timestamp: args.timestamp,
    type: 'raid',
    title:
      survivorCount === 0
        ? `Raid failed: ${attackerLossCount} attackers lost`
        : total > 0
          ? `Raid gained ${total} resources`
          : 'Raid returned empty',
    body: describeCombatReport({
      sentAttackers: args.sentAttackers,
      defenders: args.defenders,
      combat: args.combat,
      loot: args.carriedResources,
    }),
  });
};

const createLanArcadeAttackReport = (
  database: Parameters<Resolver<GameEvent<'troopMovementAttack'>>>[0],
  args: {
    eventId: number;
    villageId: number;
    timestamp: number;
    sentAttackers: CombatTroop[];
    defenders: CombatTroop[];
    combat: CombatResult;
  },
) => {
  const attackerSurvivorCount = totalTroopCount(args.combat.attackerSurvivors);
  const defenderSurvivorCount = totalTroopCount(args.combat.defenderSurvivors);

  insertLanArcadeReport(database, {
    id: `attack-${args.eventId}`,
    villageId: args.villageId,
    timestamp: args.timestamp,
    type: 'attack',
    title:
      attackerSurvivorCount === 0
        ? 'Attack failed'
        : defenderSurvivorCount === 0 && args.defenders.length > 0
          ? 'Attack cleared defenders'
          : 'Attack returned',
    body: describeCombatReport({
      sentAttackers: args.sentAttackers,
      defenders: args.defenders,
      combat: args.combat,
    }),
  });
};

"""
s = s[:helper_start] + combat_helpers + s[helper_end:]
old_attack = """export const attackMovementResolver: Resolver<
  GameEvent<'troopMovementAttack'>
> = (database, args) => {
  const { id, villageId, resolvesAt, originTileId, targetTileId, troops } = args;
  const defenderCount = countDefendersAtTile(database, targetTileId);

  // LAN Arcade: make incomplete combat visible instead of silently bypassing it.
  createLanArcadeAttackReport(database, {
    eventId: id,
    villageId,
    timestamp: resolvesAt,
    defenderCount,
  });

  createEvents<'troopMovementReturn'>(database, {
    villageId,
    troops,
    targetTileId: originTileId,
    originTileId: targetTileId,
    startsAt: resolvesAt,
    type: 'troopMovementReturn',
    originalMovementType: 'troopMovementAttack',
    originalMovementEventId: id,
    defenderCount,
  } as never);

  const targetVillageIds = database.selectValues({
    sql: selectPlayerVillageIdByTileIdQuery,
    bind: { $tile_id: targetTileId, $player_id: PLAYER_ID },
    schema: z.number(),
  });

  return {
    affectedVillageIds: [villageId, ...targetVillageIds],
  };
};
"""
new_attack = """export const attackMovementResolver: Resolver<
  GameEvent<'troopMovementAttack'>
> = (database, args) => {
  const { id, villageId, resolvesAt, originTileId, targetTileId, troops } = args;
  const defenders = selectDefendersAtTile(database, targetTileId);
  const combat = resolveLanArcadeCombat('attack', troops, defenders);

  removeCombatLosses(database, combat.defenderLosses);

  createLanArcadeAttackReport(database, {
    eventId: id,
    villageId,
    timestamp: resolvesAt,
    sentAttackers: troops,
    defenders,
    combat,
  });

  if (combat.attackerSurvivors.length > 0) {
    createEvents<'troopMovementReturn'>(database, {
      villageId,
      troops: combat.attackerSurvivors,
      targetTileId: originTileId,
      originTileId: targetTileId,
      startsAt: resolvesAt,
      type: 'troopMovementReturn',
      originalMovementType: 'troopMovementAttack',
      originalMovementEventId: id,
      attackerLosses: combat.attackerLosses,
      defenderLosses: combat.defenderLosses,
    } as never);
  }

  const targetVillageIds = database.selectValues({
    sql: selectPlayerVillageIdByTileIdQuery,
    bind: { $tile_id: targetTileId, $player_id: PLAYER_ID },
    schema: z.number(),
  });

  return {
    affectedVillageIds: [villageId, ...targetVillageIds],
  };
};
"""
if old_attack not in s:
    raise SystemExit('Failed to find previous LAN attack resolver block')
s = s.replace(old_attack, new_attack, 1)
old_raid = """export const raidMovementResolver: Resolver<GameEvent<'troopMovementRaid'>> = (
  database,
  args,
) => {
  const { id, villageId, resolvesAt, troops, originTileId, targetTileId } = args;
  const defenderCount = countDefendersAtTile(database, targetTileId);
  const carriedResources =
    defenderCount > 0
      ? emptyRaidResourceBundle()
      : raidVillageResources(
          database,
          targetTileId,
          resolvesAt,
          calculateRaidCarryCapacity(troops),
        );

  // LAN Arcade: defended raids return empty until full casualty combat exists.
  createLanArcadeRaidReport(database, {
    eventId: id,
    villageId,
    timestamp: resolvesAt,
    carriedResources,
    defenderCount,
  });

  createEvents<'troopMovementReturn'>(database, {
    villageId,
    troops,
    startsAt: resolvesAt,
    targetTileId: originTileId,
    originTileId: targetTileId,
    type: 'troopMovementReturn',
    originalMovementType: 'troopMovementRaid',
    originalMovementEventId: id,
    carriedResources,
    defenderCount,
  } as never);

  const targetVillageIds = database.selectValues({
    sql: selectPlayerVillageIdByTileIdQuery,
    bind: { $tile_id: targetTileId, $player_id: PLAYER_ID },
    schema: z.number(),
  });

  return {
    affectedVillageIds: [villageId, ...targetVillageIds],
  };
};
"""
new_raid = """export const raidMovementResolver: Resolver<GameEvent<'troopMovementRaid'>> = (
  database,
  args,
) => {
  const { id, villageId, resolvesAt, troops, originTileId, targetTileId } = args;
  const defenders = selectDefendersAtTile(database, targetTileId);
  const combat = resolveLanArcadeCombat('raid', troops, defenders);

  removeCombatLosses(database, combat.defenderLosses);

  const carriedResources = raidVillageResources(
    database,
    targetTileId,
    resolvesAt,
    calculateRaidCarryCapacity(combat.attackerSurvivors),
  );

  createLanArcadeRaidReport(database, {
    eventId: id,
    villageId,
    timestamp: resolvesAt,
    sentAttackers: troops,
    defenders,
    combat,
    carriedResources,
  });

  if (combat.attackerSurvivors.length > 0) {
    createEvents<'troopMovementReturn'>(database, {
      villageId,
      troops: combat.attackerSurvivors,
      startsAt: resolvesAt,
      targetTileId: originTileId,
      originTileId: targetTileId,
      type: 'troopMovementReturn',
      originalMovementType: 'troopMovementRaid',
      originalMovementEventId: id,
      carriedResources,
      attackerLosses: combat.attackerLosses,
      defenderLosses: combat.defenderLosses,
    } as never);
  }

  const targetVillageIds = database.selectValues({
    sql: selectPlayerVillageIdByTileIdQuery,
    bind: { $tile_id: targetTileId, $player_id: PLAYER_ID },
    schema: z.number(),
  });

  return {
    affectedVillageIds: [villageId, ...targetVillageIds],
  };
};
"""
if old_raid not in s:
    raise SystemExit('Failed to find previous LAN raid resolver block')
s = s.replace(old_raid, new_raid, 1)
resolver.write_text(s)
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
