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
  'Target',
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
  const target = extractReportField(body, 'Target');
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
    { label: 'Target', value: target },
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

# LAN Arcade hero state repair.
# If a pre-patch browser save lost the HERO in combat, the troop can be gone while
# heroes.health still says alive. Reconcile that narrow orphan state so the normal
# revive UI can appear without resetting the world.
hero_controllers = root / 'packages/api/src/http/controllers/hero-controllers.ts'
hc = hero_controllers.read_text()
hc = hc.replace(
    "import { z } from 'zod';\n",
    "import { z } from 'zod';\nimport type { DbFacade } from '@pillage-first/utils/facades/database';\n",
    1,
)
hc = hc.replace(
    "import { updateHeroResourceProductionEffects } from '../../utils/hero';\n",
    "import { onHeroDeath, updateHeroResourceProductionEffects } from '../../utils/hero';\n",
    1,
)
hero_repair_anchor = """import {
  getHeroInventorySchema,
  getHeroLoadoutSchema,
  getHeroSchema,
} from './schemas/hero-schemas';

export const getHero = createController('/players/:playerId/hero', {
"""
hero_repair_block = """import {
  getHeroInventorySchema,
  getHeroLoadoutSchema,
  getHeroSchema,
} from './schemas/hero-schemas';

const reconcileLanArcadeOrphanedHero = (
  database: DbFacade,
  playerId: number,
): void => {
  const isOrphanedAliveHero = database.selectValue({
    sql: `
      SELECT
        EXISTS (
          SELECT 1
          FROM heroes h
          WHERE
            h.player_id = $player_id
            AND h.health > 0
            AND NOT EXISTS (
              SELECT 1
              FROM troops t
                JOIN unit_ids ui ON ui.id = t.unit_id
              WHERE ui.unit = 'HERO' AND t.amount > 0
            )
            AND NOT EXISTS (
              SELECT 1
              FROM events e
              WHERE
                e.meta IS NOT NULL
                AND e.meta LIKE '%"unitId":"HERO"%'
            )
        ) AS is_orphaned_alive_hero;
    `,
    bind: { $player_id: playerId },
    schema: z.coerce.boolean(),
  });

  if (!isOrphanedAliveHero) {
    return;
  }

  const now = Date.now();
  database.exec({
    sql: 'UPDATE heroes SET health = 0 WHERE player_id = $player_id AND health > 0;',
    bind: { $player_id: playerId },
  });
  onHeroDeath(database, now);
};

export const getHero = createController('/players/:playerId/hero', {
"""
if hero_repair_anchor not in hc:
    raise SystemExit('Failed to find hero controller anchor')
hc = hc.replace(hero_repair_anchor, hero_repair_block, 1)
get_hero_handler = """})(({ database, path: { playerId } }) => {
  const row = database.selectObject({
"""
get_hero_handler_replacement = """})(({ database, path: { playerId } }) => {
  reconcileLanArcadeOrphanedHero(database, playerId);

  const row = database.selectObject({
"""
if get_hero_handler not in hc:
    raise SystemExit('Failed to find getHero handler anchor')
hc = hc.replace(get_hero_handler, get_hero_handler_replacement, 1)
hero_controllers.write_text(hc)

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

type TargetIdentity = {
  tileId: number;
  x: number;
  y: number;
  villageId: number | null;
  villageName: string | null;
  villageSlug: string | null;
  playerId: number | null;
  playerName: string | null;
  playerSlug: string | null;
};

const targetIdentitySchema = z.strictObject({
  tileId: z.number(),
  x: z.number(),
  y: z.number(),
  villageId: z.number().nullable(),
  villageName: z.string().nullable(),
  villageSlug: z.string().nullable(),
  playerId: z.number().nullable(),
  playerName: z.string().nullable(),
  playerSlug: z.string().nullable(),
});

const selectTargetIdentity = (
  database: Parameters<Resolver<GameEvent<'troopMovementRaid'>>>[0],
  targetTileId: number,
): TargetIdentity => {
  const target = database.selectObject({
    sql: `
      SELECT
        t.id AS tileId,
        t.x,
        t.y,
        v.id AS villageId,
        v.name AS villageName,
        v.slug AS villageSlug,
        p.id AS playerId,
        p.name AS playerName,
        p.slug AS playerSlug
      FROM
        tiles t
          LEFT JOIN villages v ON v.tile_id = t.id
          LEFT JOIN players p ON p.id = v.player_id
      WHERE
        t.id = $target_tile_id;
    `,
    bind: { $target_tile_id: targetTileId },
    schema: targetIdentitySchema,
  });

  return target ?? {
    tileId: targetTileId,
    x: 0,
    y: 0,
    villageId: null,
    villageName: null,
    villageSlug: null,
    playerId: null,
    playerName: null,
    playerSlug: null,
  };
};

const describeTargetIdentity = (target: TargetIdentity) => {
  const coordinates = `(${target.x}|${target.y})`;
  const villageLabel =
    target.villageName ?? target.villageSlug ??
    (target.villageId === null ? 'free tile' : `Village #${target.villageId}`);
  const playerLabel =
    target.playerName ?? target.playerSlug ??
    (target.playerId === null ? null : `player #${target.playerId}`);

  return playerLabel
    ? `${villageLabel} ${coordinates} owned by ${playerLabel}`
    : `${villageLabel} ${coordinates}`;
};

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

const hasHeroLoss = (losses: CombatTroop[]) => {
  return losses.some(({ unitId, amount }) => unitId === 'HERO' && amount > 0);
};

const markHeroDeadFromCombatLosses = (
  database: Parameters<Resolver<GameEvent<'troopMovementRaid'>>>[0],
  losses: CombatTroop[],
  timestamp: number,
) => {
  if (!hasHeroLoss(losses)) {
    return;
  }

  removeTroops(
    database,
    losses.filter(({ unitId, amount }) => unitId === 'HERO' && amount > 0),
  );
  database.exec({
    sql: 'UPDATE heroes SET health = 0 WHERE player_id = $player_id AND health > 0;',
    bind: { $player_id: PLAYER_ID },
  });
  onHeroDeath(database, timestamp);
};

const describeCombatReport = (args: {
  target: TargetIdentity;
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
    `Target: ${describeTargetIdentity(args.target)}.`,
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
    target: TargetIdentity;
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
      target: args.target,
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
    target: TargetIdentity;
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
      target: args.target,
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
  const target = selectTargetIdentity(database, targetTileId);
  const defenders = selectDefendersAtTile(database, targetTileId);
  const combat = resolveLanArcadeCombat('attack', troops, defenders);

  removeCombatLosses(database, combat.defenderLosses);
  markHeroDeadFromCombatLosses(database, combat.attackerLosses, resolvesAt);

  createLanArcadeAttackReport(database, {
    eventId: id,
    villageId,
    timestamp: resolvesAt,
    target,
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
  const target = selectTargetIdentity(database, targetTileId);
  const defenders = selectDefendersAtTile(database, targetTileId);
  const combat = resolveLanArcadeCombat('raid', troops, defenders);

  removeCombatLosses(database, combat.defenderLosses);
  markHeroDeadFromCombatLosses(database, combat.attackerLosses, resolvesAt);

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
    target,
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

# LAN Arcade phase upgrade patch 2026-06-22 phase 1: UI clarity, farm lists, scout labels, simulator.
python3 - <<'PY'
from pathlib import Path

root = Path('.')

def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    if old not in text:
        raise SystemExit(f"Expected text not found in {path}: {old[:120]!r}")
    path.write_text(text.replace(old, new, 1))

# 1) Replace several missing unit icons with readable existing icons.
icons_path = root / 'apps/web/app/components/icons/icons.tsx'
icons = icons_path.read_text()
icon_replacements = {
    "  swordsman: (props) => icons.missingIcon(props),": "  swordsman: (props) => <LuSword {...props} />,",
    "  gaulRam: (props) => icons.missingIcon(props),": "  gaulRam: (props) => <GiIBeam {...props} />,",
    "  teutonicRam: (props) => icons.missingIcon(props),": "  teutonicRam: (props) => <GiIBeam {...props} />,",
    "  slaveMilitia: (props) => icons.missingIcon(props),": "  slaveMilitia: (props) => <GiBarbedSpear {...props} />,",
    "  ashWarden: (props) => icons.missingIcon(props),": "  ashWarden: (props) => <BsShieldFill {...props} />,",
    "  khopeshWarrior: (props) => icons.missingIcon(props),": "  khopeshWarrior: (props) => <LuSword {...props} />,",
    "  egyptianRam: (props) => icons.missingIcon(props),": "  egyptianRam: (props) => <GiIBeam {...props} />,",
    "  mercenary: (props) => icons.missingIcon(props),": "  mercenary: (props) => <GiBattleAxe {...props} />,",
    "  bowman: (props) => icons.missingIcon(props),": "  bowman: (props) => <GiBarbedSpear {...props} />,",
    "  hunRam: (props) => icons.missingIcon(props),": "  hunRam: (props) => <GiIBeam {...props} />,",
    "  pikeman: (props) => icons.missingIcon(props),": "  pikeman: (props) => <GiBarbedSpear {...props} />,",
    "  thornedWarrior: (props) => icons.missingIcon(props),": "  thornedWarrior: (props) => <GiSpikedMace {...props} />,",
    "  guardsman: (props) => icons.missingIcon(props),": "  guardsman: (props) => <BsShieldFill {...props} />,",
    "  natarianRam: (props) => icons.missingIcon(props),": "  natarianRam: (props) => <GiIBeam {...props} />,",
}
for old, new in icon_replacements.items():
    icons = icons.replace(old, new)
icons_path.write_text(icons)

# 2) Enrich farm-list DTOs so the farm-list page can show usable target rows.
farm_dto_path = root / 'packages/types/src/dtos/farm-list.ts'
farm_dto_path.write_text('''import { z } from 'zod';

export const createFarmListDtoSchema = z.strictObject({
  name: z.string(),
  villageId: z.number(),
});

export const updateFarmListDtoSchema = z.strictObject({
  name: z.string(),
});

export const farmListDtoSchema = z.strictObject({
  id: z.number(),
  name: z.string(),
  villageId: z.number(),
  targetCount: z.number(),
});

export const farmListTargetDtoSchema = z.strictObject({
  tileId: z.number(),
  x: z.number(),
  y: z.number(),
  villageName: z.string().nullable(),
  playerName: z.string().nullable(),
  playerSlug: z.string().nullable(),
  tribe: z.string().nullable(),
  population: z.number().nullable(),
});

export const farmListDetailsDtoSchema = farmListDtoSchema.extend({
  tileIds: z.array(z.number()),
  targets: z.array(farmListTargetDtoSchema),
});

export type CreateFarmListDto = z.infer<typeof createFarmListDtoSchema>;
export type UpdateFarmListDto = z.infer<typeof updateFarmListDtoSchema>;
export type FarmListDto = z.infer<typeof farmListDtoSchema>;
export type FarmListTargetDto = z.infer<typeof farmListTargetDtoSchema>;
export type FarmListDetailsDto = z.infer<typeof farmListDetailsDtoSchema>;
''')

# 3) Return target metadata from the farm-list details endpoint.
farm_controller_path = root / 'packages/api/src/http/controllers/farm-list-controllers.ts'
farm_controller = farm_controller_path.read_text()
farm_controller = farm_controller.replace(
    "  farmListDetailsDtoSchema,\n  farmListDtoSchema,",
    "  farmListDetailsDtoSchema,\n  farmListDtoSchema,\n  farmListTargetDtoSchema,",
)
old_get = '''export const getFarmList = (request: Request, response: Response) => {
  const farmListId = z.coerce.number().parse(request.params.farmListId);
  const farmList = selectFarmListByIdQuery(database, farmListId);
  const tileIds = selectFarmListTileIdsQuery(database, farmListId);

  response.json(farmListDetailsDtoSchema.parse({
    ...farmList,
    tileIds,
  }));
};
'''
new_get = '''export const getFarmList = (request: Request, response: Response) => {
  const farmListId = z.coerce.number().parse(request.params.farmListId);
  const farmList = selectFarmListByIdQuery(database, farmListId);
  const tileIds = selectFarmListTileIdsQuery(database, farmListId);
  const targets = database.selectObjects({
    sql: `
      SELECT
        flt.tile_id AS tileId,
        t.x AS x,
        t.y AS y,
        v.name AS villageName,
        p.name AS playerName,
        p.slug AS playerSlug,
        ti.tribe AS tribe,
        CAST(COALESCE(ROUND(SUM(CASE WHEN ei.effect = 'wheatProduction' AND e.source = 'building' THEN -e.value ELSE 0 END)), 0) AS INTEGER) AS population
      FROM farm_list_tiles flt
      INNER JOIN tiles t ON t.id = flt.tile_id
      LEFT JOIN villages v ON v.tile_id = t.id
      LEFT JOIN players p ON p.id = v.player_id
      LEFT JOIN tribe_ids ti ON ti.id = p.tribe_id
      LEFT JOIN effects e ON e.village_id = v.id
      LEFT JOIN effect_ids ei ON ei.id = e.effect_id
      WHERE flt.farm_list_id = $farm_list_id
      GROUP BY flt.tile_id, t.x, t.y, v.name, p.name, p.slug, ti.tribe
      ORDER BY t.y ASC, t.x ASC
    `,
    parameters: { farm_list_id: farmListId },
    schema: farmListTargetDtoSchema,
  });

  response.json(farmListDetailsDtoSchema.parse({
    ...farmList,
    tileIds,
    targets,
  }));
};
'''
if old_get in farm_controller:
    farm_controller = farm_controller.replace(old_get, new_get, 1)
else:
    create_start = "export const getFarmList = createController('/farm-lists/:farmListId', {"
    delete_start = "\n\nexport const deleteFarmList = createController("
    start = farm_controller.find(create_start)
    end = farm_controller.find(delete_start, start)
    if start == -1 or end == -1:
        raise SystemExit('getFarmList controller shape not found')
    new_create_get = '''export const getFarmList = createController('/farm-lists/:farmListId', {
  summary: 'Get farm list details',
  requestParams: {
    path: z.strictObject({
      farmListId: z.coerce.number(),
    }),
  },
  response: farmListDetailsDtoSchema,
})(({ database, path: { farmListId } }) => {
  const farmList = database.selectObject({
    sql: selectFarmListQuery,
    bind: { $farm_list_id: farmListId },
    schema: farmListSchema,
  })!;

  const tileRows = database.selectObjects({
    sql: selectFarmListTileIdsQuery,
    bind: { $farm_list_id: farmListId },
    schema: farmListTileRowSchema,
  });

  const targets = database.selectObjects({
    sql: `
      SELECT
        flt.tile_id AS tileId,
        t.x AS x,
        t.y AS y,
        v.name AS villageName,
        p.name AS playerName,
        p.slug AS playerSlug,
        ti.tribe AS tribe,
        CAST(COALESCE(ROUND(SUM(CASE WHEN ei.effect = 'wheatProduction' AND e.source = 'building' THEN -e.value ELSE 0 END)), 0) AS INTEGER) AS population
      FROM farm_list_tiles flt
      INNER JOIN tiles t ON t.id = flt.tile_id
      LEFT JOIN villages v ON v.tile_id = t.id
      LEFT JOIN players p ON p.id = v.player_id
      LEFT JOIN tribe_ids ti ON ti.id = p.tribe_id
      LEFT JOIN effects e ON e.village_id = v.id
      LEFT JOIN effect_ids ei ON ei.id = e.effect_id
      WHERE flt.farm_list_id = $farm_list_id
      GROUP BY flt.tile_id, t.x, t.y, v.name, p.name, p.slug, ti.tribe
      ORDER BY t.y ASC, t.x ASC
    `,
    bind: { $farm_list_id: farmListId },
    schema: farmListTargetDtoSchema,
  });

  return {
    ...farmList,
    tileIds: tileRows.map((r) => r.tile_id),
    targets,
  };
});'''
    farm_controller = farm_controller[:start] + new_create_get + farm_controller[end:]
farm_controller_path.write_text(farm_controller)

# 4) Fix farm-list cache invalidation so add/remove appears immediately.
farm_hook_path = root / 'apps/web/app/(game)/(village-slug)/hooks/use-farm-lists.ts'
farm_hook = farm_hook_path.read_text()
farm_hook = farm_hook.replace(
    '''      [
        [farmListsCacheKey, currentVillage.id],
      ],''',
    '''      [
        [farmListsCacheKey],
        [farmListsCacheKey, currentVillage.id],
      ],''',
)
farm_hook = farm_hook.replace(
    '''      [
        [farmListsCacheKey, currentVillage.id],
      ],''',
    '''      [
        [farmListsCacheKey],
        [farmListsCacheKey, currentVillage.id],
      ],''',
)
farm_hook_path.write_text(farm_hook)

# 5) Make the farm-list page show targets and provide direct raid links/removal.
farm_list_page_path = root / 'apps/web/app/(game)/(village-slug)/components/rally-point-farm-list.tsx'
farm_list_page_path.write_text('''import { useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { Link } from 'react-router';

import { Bookmark, Pencil, Trash2 } from 'lucide-react';

import { CreateFarmListModal } from 'app/(game)/(village-slug)/components/create-farm-list-modal';
import { EditFarmListModal } from 'app/(game)/(village-slug)/components/edit-farm-list-modal';
import { Section } from 'app/(game)/(village-slug)/components/section';
import { farmListsCacheKey } from 'app/(game)/constants/query-keys';
import { useFarmLists } from 'app/(game)/(village-slug)/hooks/use-farm-lists';
import { usePlayerVillageListing } from 'app/(game)/(village-slug)/hooks/use-player-village-listing';
import { Button } from 'app/components/buttons/button';
import { Text } from 'app/components/text';
import { useDialog } from 'app/hooks/use-dialog';

const FarmListTargets = ({ farmListId, targetCount }: { farmListId: number; targetCount: number }) => {
  const { getFarmList, removeTileFromFarmList } = useFarmLists();
  const { data: details, isLoading } = useQuery({
    queryKey: [farmListsCacheKey, farmListId],
    queryFn: () => getFarmList(farmListId),
    enabled: targetCount > 0,
  });

  if (targetCount === 0) {
    return (
      <div className="flex flex-col gap-2 p-4 text-center text-muted-foreground">
        <Text>No targets in this farm list yet.</Text>
        <Text className="text-sm">Open a village on the map and use Add to farm list.</Text>
      </div>
    );
  }

  if (isLoading || !details) {
    return <div className="p-4 text-sm text-muted-foreground">Loading farm targets...</div>;
  }

  return (
    <div className="divide-y">
      {details.targets.map((target) => {
        const title = target.villageName ?? `Tile (${target.x}|${target.y})`;
        const owner = target.playerName ? ` by ${target.playerName}` : '';
        return (
          <div className="flex flex-wrap items-center justify-between gap-3 p-3" key={target.tileId}>
            <div className="min-w-48">
              <Text className="font-semibold">{title} ({target.x}|{target.y})</Text>
              <Text className="text-sm text-muted-foreground">
                {target.tribe ? `${target.tribe} village${owner}` : `Map target${owner}`}
                {typeof target.population === 'number' && target.population > 0 ? ` - pop ${target.population}` : ''}
              </Text>
            </div>
            <div className="flex items-center gap-2">
              <Button size="small" variant="outline" asChild>
                <Link to={`?tab=send-troops&rally-point-send-troops-tab=attack-or-raid&x=${target.x}&y=${target.y}`}>Raid</Link>
              </Button>
              <Button
                aria-label={`Remove ${title} from farm list`}
                size="icon"
                variant="ghost"
                onClick={() => removeTileFromFarmList(farmListId, target.tileId)}
              >
                <Trash2 className="size-4" />
              </Button>
            </div>
          </div>
        );
      })}
    </div>
  );
};

export const RallyPointFarmList = () => {
  const { farmLists, deleteFarmList } = useFarmLists();
  const { playerVillages } = usePlayerVillageListing();
  const { open } = useDialog();

  const farmListsByVillage = useMemo(() => {
    return playerVillages.map((village) => ({
      ...village,
      farmLists: farmLists.filter((farmList) => farmList.villageId === village.id),
    }));
  }, [farmLists, playerVillages]);

  return (
    <Section>
      <div className="flex items-start justify-between gap-4">
        <div>
          <Text as="h2">Farm list</Text>
          <Text>
            The Farm List lets you save repeat raid targets. Add targets from the map, then come back here to open pre-filled raid orders.
          </Text>
          <Text className="font-semibold">You currently have {farmLists.length} farm {farmLists.length === 1 ? 'list' : 'lists'}.</Text>
        </div>
        <Button aria-label="Bookmark farm list" size="icon" variant="outline">
          <Bookmark className="size-5" />
        </Button>
      </div>

      <div className="flex justify-end">
        <Button size="small" onClick={() => open(<CreateFarmListModal />)}>
          Create new list
        </Button>
      </div>

      {farmListsByVillage.map((village) => (
        <div className="mt-5" key={village.id}>
          <Text as="h3">{village.name}</Text>
          {village.farmLists.length === 0 ? (
            <div className="mt-2 rounded border p-4 text-sm text-muted-foreground">No farm lists for this village yet.</div>
          ) : (
            <div className="mt-2 flex flex-col gap-4">
              {village.farmLists.map((farmList) => (
                <div className="overflow-hidden rounded border" key={farmList.id}>
                  <div className="flex flex-wrap items-center justify-between gap-3 bg-muted/40 p-3">
                    <div>
                      <Text className="font-semibold">{farmList.name}</Text>
                      <Text className="text-sm text-muted-foreground">{farmList.targetCount}/100 targets</Text>
                    </div>
                    <div className="flex items-center gap-2">
                      <Button aria-label="Edit farm list" size="icon" variant="ghost" onClick={() => open(<EditFarmListModal farmListId={farmList.id} name={farmList.name} />)}>
                        <Pencil className="size-4" />
                      </Button>
                      <Button aria-label="Delete farm list" size="icon" variant="ghost" onClick={() => deleteFarmList(farmList.id)}>
                        <Trash2 className="size-4 text-destructive" />
                      </Button>
                    </div>
                  </div>
                  <FarmListTargets farmListId={farmList.id} targetCount={farmList.targetCount} />
                </div>
              ))}
            </div>
          )}
        </div>
      ))}
    </Section>
  );
};
''')

# 6) Improve map modal scout intel labels, add farm-list actions, and stop marker popover closing while typing.
tile_modal_path = root / 'apps/web/app/(game)/(village-slug)/(map)/components/tile-modal.tsx'
tile_modal = tile_modal_path.read_text()
if "useFarmLists" not in tile_modal:
    tile_modal = tile_modal.replace(
        "import { useCurrentVillage } from 'app/(game)/(village-slug)/hooks/current-village-context';",
        "import { useCurrentVillage } from 'app/(game)/(village-slug)/hooks/current-village-context';\nimport { useFarmLists } from 'app/(game)/(village-slug)/hooks/use-farm-lists';",
    )
tile_modal = tile_modal.replace(
    '<Popover open={isOpen} onOpenChange={setIsOpen}>',
    '<Popover modal open={isOpen} onOpenChange={setIsOpen}>',
)
tile_modal = tile_modal.replace(
    '<PopoverContent align="end" className="w-72" side="bottom">',
    '<PopoverContent align="end" className="w-72" side="bottom" onClick={(event) => event.stopPropagation()} onPointerDownOutside={(event) => event.preventDefault()}>',
)
tile_modal = tile_modal.replace(
'''          <div className="flex flex-wrap items-center gap-2" key={unitId}>
            <div className="flex items-center gap-1 rounded border px-2 py-1">
              <Icon className="size-4" type={unitIdToUnitIconMapper(unitId)} />
              <span>{amount}</span>
            </div>
          </div>''',
'''          <div className="flex flex-wrap items-center gap-2" key={unitId}>
            <div className="flex items-center gap-1 rounded border px-2 py-1" title={t(`UNITS.${unitId}.NAME`)}>
              <Icon className="size-4" type={unitIdToUnitIconMapper(unitId)} />
              <span>{amount}</span>
              <span className="text-xs text-muted-foreground">{t(`UNITS.${unitId}.NAME`)}</span>
            </div>
          </div>''')
farm_actions_component = r'''
const TileModalFarmListActions = ({ tile }: TileModalProps) => {
  const { farmLists, addTileToFarmList } = useFarmLists();
  const currentVillage = useCurrentVillage();

  if (!isOccupiedOccupiableTile(tile) || tile.owner.id === PLAYER_ID) {
    return null;
  }

  const availableLists = farmLists.filter((farmList) => farmList.villageId === currentVillage.id);

  if (availableLists.length === 0) {
    return <Text className="text-sm text-muted-foreground">Create a farm list at the Rally Point to save this as a repeat raid target.</Text>;
  }

  return (
    <div className="flex flex-wrap gap-2">
      {availableLists.map((farmList) => (
        <Button key={farmList.id} size="small" variant="outline" onClick={() => addTileToFarmList(farmList.id, tile.id)}>
          Add to {farmList.name}
        </Button>
      ))}
    </div>
  );
};

'''
if 'const TileModalFarmListActions' not in tile_modal:
    tile_modal = tile_modal.replace('const TileModalPlayerInfo = ({ tile }: TileModalProps) => {', farm_actions_component + 'const TileModalPlayerInfo = ({ tile }: TileModalProps) => {', 1)
tile_modal = tile_modal.replace(
'''              <Suspense fallback={<Skeleton className="h-16 w-full" />}>
                <TileModalTroopIntel tile={tile} />
              </Suspense>
              <Link className="font-semibold text-green-600" to={`../../village/39?tab=send-troops&rally-point-send-troops-tab=attack-or-raid&x=${tile.x}&y=${tile.y}`}>
                Attack or raid
              </Link>''',
'''              <Suspense fallback={<Skeleton className="h-16 w-full" />}>
                <TileModalTroopIntel tile={tile} />
              </Suspense>
              <TileModalFarmListActions tile={tile} />
              <Link className="font-semibold text-green-600" to={`../../village/39?tab=send-troops&rally-point-send-troops-tab=attack-or-raid&x=${tile.x}&y=${tile.y}`}>
                Attack or raid
              </Link>''')
tile_modal_path.write_text(tile_modal)

# 7) Add named defender intel to map hover tooltips and explain treasure pickup.
tile_tooltip_path = root / 'apps/web/app/(game)/(village-slug)/(map)/components/tile-tooltip.tsx'
tile_tooltip = tile_tooltip_path.read_text()
tile_tooltip = tile_tooltip.replace(
'''        <TileTooltipVillageResources villageId={tile.village.id} />
        <TileTooltipWorldItem tile={tile} />
      </div>''',
'''        <TileTooltipVillageResources villageId={tile.village.id} />
        <TileTooltipDefenders tile={tile} />
        <TileTooltipWorldItem tile={tile} />
      </div>''')
defender_component = r'''
const TileTooltipDefenders = ({ tile }: { tile: OccupiedOccupiableTile }) => {
  const { t } = useTranslation();
  const { tileTroops, isLoading } = useTileTroops(tile.id);
  const visibleTroops = tileTroops.filter(({ amount }) => amount > 0);

  if (isLoading || visibleTroops.length === 0) {
    return null;
  }

  return (
    <div className="mt-2 flex flex-col gap-1">
      <Text className="font-semibold">Scout intel</Text>
      <div className="flex flex-wrap gap-2">
        {visibleTroops.map(({ unitId, amount }) => (
          <span className="flex items-center gap-1 rounded bg-background/20 px-1" key={unitId} title={t(`UNITS.${unitId}.NAME`)}>
            <Icon className="size-3" type={unitIdToUnitIconMapper(unitId)} />
            <span>{amount}</span>
            <span className="text-xs">{t(`UNITS.${unitId}.NAME`)}</span>
          </span>
        ))}
      </div>
    </div>
  );
};

'''
if 'const TileTooltipDefenders' not in tile_tooltip:
    tile_tooltip = tile_tooltip.replace('const TileTooltipAnimals = ({ tile }: { tile: OccupiedOasisTile }) => {', defender_component + 'const TileTooltipAnimals = ({ tile }: { tile: OccupiedOasisTile }) => {', 1)
tile_tooltip = tile_tooltip.replace(
'''  return <Text>{t(`ITEMS.${worldItem.itemId}.NAME`)} x {worldItem.amount}</Text>;''',
'''  return (
    <div className="mt-1">
      <Text>{t(`ITEMS.${worldItem.itemId}.NAME`)} x {worldItem.amount}</Text>
      <Text className="text-xs text-muted-foreground">Send a surviving Hero raid to collect treasure.</Text>
    </div>
  );''')
tile_tooltip_path.write_text(tile_tooltip)

# 8) Turn the rally-point simulator from placeholder text into a lightweight LAN-combat calculator.
simulator_path = root / 'apps/web/app/(game)/(village-slug)/components/rally-point-simulator.tsx'
simulator_path.write_text('''import { useMemo, useState } from 'react';

import { Bookmark } from 'lucide-react';

import { Section } from 'app/(game)/(village-slug)/components/section';
import { Button } from 'app/components/buttons/button';
import { Input } from 'app/components/input';
import { Label } from 'app/components/label';
import { Text } from 'app/components/text';

const numberOrZero = (value: string) => Number.isFinite(Number(value)) ? Math.max(0, Number(value)) : 0;

export const RallyPointSimulator = () => {
  const [attackPower, setAttackPower] = useState('1000');
  const [defencePower, setDefencePower] = useState('700');
  const [attackerCount, setAttackerCount] = useState('100');
  const [defenderCount, setDefenderCount] = useState('60');
  const [mode, setMode] = useState<'raid' | 'attack'>('raid');

  const result = useMemo(() => {
    const attack = numberOrZero(attackPower);
    const defence = numberOrZero(defencePower);
    const attackers = numberOrZero(attackerCount);
    const defenders = numberOrZero(defenderCount);
    const total = Math.max(1, attack + defence);
    const attackerLossRatio = mode === 'raid'
      ? Math.min(1, Math.max(0, defence / total) * 0.65)
      : Math.min(1, Math.max(0, defence / total) * 1.1);
    const defenderLossRatio = mode === 'raid'
      ? Math.min(1, Math.max(0, attack / total) * 0.45)
      : Math.min(1, Math.max(0, attack / total) * 1.15);
    const attackerLosses = Math.min(attackers, Math.ceil(attackers * attackerLossRatio));
    const defenderLosses = Math.min(defenders, Math.ceil(defenders * defenderLossRatio));
    const survivingAttackers = Math.max(0, attackers - attackerLosses);
    const survivingDefenders = Math.max(0, defenders - defenderLosses);

    return { attackerLosses, defenderLosses, survivingAttackers, survivingDefenders };
  }, [attackPower, defencePower, attackerCount, defenderCount, mode]);

  return (
    <Section>
      <div className="flex items-start justify-between gap-4">
        <div>
          <Text as="h2">Simulator</Text>
          <Text>Estimate LAN Arcade combat before sending a raid or normal attack. Actual results still depend on the exact unit stats and surviving carry capacity.</Text>
        </div>
        <Button aria-label="Bookmark simulator" size="icon" variant="outline">
          <Bookmark className="size-5" />
        </Button>
      </div>

      <div className="mt-4 grid gap-4 md:grid-cols-2">
        <Label className="flex flex-col gap-2">Attack power
          <Input inputMode="numeric" value={attackPower} onChange={(event) => setAttackPower(event.target.value)} />
        </Label>
        <Label className="flex flex-col gap-2">Defence power
          <Input inputMode="numeric" value={defencePower} onChange={(event) => setDefencePower(event.target.value)} />
        </Label>
        <Label className="flex flex-col gap-2">Attackers sent
          <Input inputMode="numeric" value={attackerCount} onChange={(event) => setAttackerCount(event.target.value)} />
        </Label>
        <Label className="flex flex-col gap-2">Defenders present
          <Input inputMode="numeric" value={defenderCount} onChange={(event) => setDefenderCount(event.target.value)} />
        </Label>
      </div>

      <div className="mt-4 flex gap-2">
        <Button size="small" variant={mode === 'raid' ? 'default' : 'outline'} onClick={() => setMode('raid')}>Raid</Button>
        <Button size="small" variant={mode === 'attack' ? 'default' : 'outline'} onClick={() => setMode('attack')}>Normal attack</Button>
      </div>

      <div className="mt-4 grid gap-3 md:grid-cols-4">
        <div className="rounded border p-3"><Text className="text-sm text-muted-foreground">Attacker losses</Text><Text className="font-semibold">{result.attackerLosses}</Text></div>
        <div className="rounded border p-3"><Text className="text-sm text-muted-foreground">Defender losses</Text><Text className="font-semibold">{result.defenderLosses}</Text></div>
        <div className="rounded border p-3"><Text className="text-sm text-muted-foreground">Attackers return</Text><Text className="font-semibold">{result.survivingAttackers}</Text></div>
        <div className="rounded border p-3"><Text className="text-sm text-muted-foreground">Defenders remain</Text><Text className="font-semibold">{result.survivingDefenders}</Text></div>
      </div>

      <Text className="mt-4 text-sm text-muted-foreground">
        Raids can return with loot if attackers survive. Normal attacks are harsher and are intended for clearing defenders rather than farming resources.
      </Text>
    </Section>
  );
};
''')
PY

# LAN Arcade phase upgrade patch 2026-06-22 phase 2: scout-only intel missions and clearer briefing hints.
python3 - <<'PY'
from pathlib import Path

root = Path('.')
resolver_path = root / 'packages/api/src/http/events/resolvers/troop-movement-resolver.ts'
resolver = resolver_path.read_text()
resolver = resolver.replace(
    "type: 'attack' | 'raid';",
    "type: 'attack' | 'raid' | 'scout-attack' | 'scout-defence';",
    1,
)
helper_marker = "const calculateRaidCarryCapacity = (troops: GameEvent<'troopMovementRaid'>['troops']) => {"
helper = r'''
const isLanArcadeScoutUnit = (unitId: CombatTroop['unitId']) => {
  return unitId.endsWith('_SCOUT');
};

const isLanArcadeScoutOnlyMovement = (troops: CombatTroop[]) => {
  return troops.length > 0 && troops.every(({ unitId }) => isLanArcadeScoutUnit(unitId));
};

const selectLanArcadeTargetResources = (
  database: Parameters<Resolver<GameEvent<'troopMovementRaid'>>>[0],
  targetTileId: number,
  timestamp: number,
): RaidResourceBundle | null => {
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
    return null;
  }

  updateVillageResourcesAt(database, target.villageId, timestamp);

  const refreshed = database.selectObject({
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

  return [refreshed.wood, refreshed.clay, refreshed.iron, refreshed.wheat];
};

const createLanArcadeScoutReport = (
  database: Parameters<Resolver<GameEvent<'troopMovementRaid'>>>[0],
  args: {
    eventId: number;
    villageId: number;
    timestamp: number;
    target: TargetIdentity;
    scouts: CombatTroop[];
    defenders: CombatTroop[];
    resources: RaidResourceBundle | null;
  },
) => {
  insertLanArcadeReport(database, {
    id: `scout-${args.eventId}`,
    villageId: args.villageId,
    timestamp: args.timestamp,
    type: 'scout-attack',
    title: `Scouted ${describeTargetIdentity(args.target)}`,
    body: [
      `Target: ${describeTargetIdentity(args.target)}`,
      `Scouts sent: ${summarizeTroops(args.scouts)}`,
      `Defenders present: ${summarizeTroops(args.defenders)}`,
      `Resources visible: ${args.resources ? formatRaidLoot(args.resources) : 'none'}`,
      'Outcome: scouts returned with intel. Scout-only missions do not loot resources.',
    ].join('\n'),
  });
};

'''
if 'const isLanArcadeScoutUnit' not in resolver:
    if helper_marker not in resolver:
        raise SystemExit('raid carry marker not found for scout helper insertion')
    resolver = resolver.replace(helper_marker, helper + helper_marker, 1)
old_attack = '''  const target = selectTargetIdentity(database, targetTileId);
  const defenders = selectDefendersAtTile(database, targetTileId);
  const combat = resolveLanArcadeCombat('attack', troops, defenders);
'''
new_attack = '''  const target = selectTargetIdentity(database, targetTileId);
  const defenders = selectDefendersAtTile(database, targetTileId);

  if (isLanArcadeScoutOnlyMovement(troops)) {
    createLanArcadeScoutReport(database, {
      eventId: id,
      villageId,
      timestamp: resolvesAt,
      target,
      scouts: troops,
      defenders,
      resources: selectLanArcadeTargetResources(database, targetTileId, resolvesAt),
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
    } as never);

    const targetVillageIds = database.selectValues({
      sql: selectPlayerVillageIdByTileIdQuery,
      bind: { $tile_id: targetTileId, $player_id: PLAYER_ID },
      schema: z.number(),
    });

    return {
      affectedVillageIds: [villageId, ...targetVillageIds],
    };
  }

  const combat = resolveLanArcadeCombat('attack', troops, defenders);
'''
if old_attack not in resolver:
    raise SystemExit('attack resolver insertion point not found')
resolver = resolver.replace(old_attack, new_attack, 1)
old_raid = '''  const target = selectTargetIdentity(database, targetTileId);
  const defenders = selectDefendersAtTile(database, targetTileId);
  const combat = resolveLanArcadeCombat('raid', troops, defenders);
'''
new_raid = '''  const target = selectTargetIdentity(database, targetTileId);
  const defenders = selectDefendersAtTile(database, targetTileId);

  if (isLanArcadeScoutOnlyMovement(troops)) {
    createLanArcadeScoutReport(database, {
      eventId: id,
      villageId,
      timestamp: resolvesAt,
      target,
      scouts: troops,
      defenders,
      resources: selectLanArcadeTargetResources(database, targetTileId, resolvesAt),
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
    } as never);

    const targetVillageIds = database.selectValues({
      sql: selectPlayerVillageIdByTileIdQuery,
      bind: { $tile_id: targetTileId, $player_id: PLAYER_ID },
      schema: z.number(),
    });

    return {
      affectedVillageIds: [villageId, ...targetVillageIds],
    };
  }

  const combat = resolveLanArcadeCombat('raid', troops, defenders);
'''
if old_raid not in resolver:
    raise SystemExit('raid resolver insertion point not found')
resolver = resolver.replace(old_raid, new_raid, 1)
resolver_path.write_text(resolver)

# Add a clear hint in the attack/raid briefing when only scouts are selected.
attack_form_path = root / 'apps/web/app/(game)/(village-slug)/components/send-troops/attack-raid-form.tsx'
attack_form = attack_form_path.read_text()
attack_form = attack_form.replace(
'''  const selectedTroopCount = useMemo(() => {
    return (units ?? []).reduce((total, unit) => total + unit.selected, 0);
  }, [units]);
''',
'''  const selectedTroopCount = useMemo(() => {
    return (units ?? []).reduce((total, unit) => total + unit.selected, 0);
  }, [units]);
  const selectedUnits = useMemo(() => (units ?? []).filter((unit) => unit.selected > 0), [units]);
  const isScoutOnlyMission = selectedUnits.length > 0 && selectedUnits.every((unit) => unit.unitId.endsWith('_SCOUT'));
''')
attack_form = attack_form.replace(
'''        <div>
          <Text className="text-sm font-medium">{t('Scout intel')}</Text>
''',
'''        {isScoutOnlyMission ? (
          <Text className="rounded-md border border-border bg-muted/40 p-2 text-sm text-muted-foreground">
            {t('Scout-only missions return an intel report and do not loot resources.')}
          </Text>
        ) : null}
        <div>
          <Text className="text-sm font-medium">{t('Scout intel')}</Text>
''')
attack_form_path.write_text(attack_form)
PY

# LAN Arcade phase upgrade patch 2026-06-22 phase 3: lazy NPC recovery and hero treasure collection.
python3 - <<'PY'
from pathlib import Path

root = Path('.')
resolver_path = root / 'packages/api/src/http/events/resolvers/troop-movement-resolver.ts'
resolver = resolver_path.read_text()
if "getItemDefinition" not in resolver:
    resolver = resolver.replace(
        "import { getUnitDefinition } from '@pillage-first/game-assets/utils/units';",
        "import { getUnitDefinition } from '@pillage-first/game-assets/utils/units';\nimport { getItemDefinition } from '@pillage-first/game-assets/utils/items';",
        1,
    )
# Describe optional collected treasure in raid reports.
resolver = resolver.replace(
'''    loot?: RaidResourceBundle;
  },''',
'''    loot?: RaidResourceBundle;
    treasures?: string[];
  },''',
1)
resolver = resolver.replace(
'''  if (details.loot) {
    lines.push(`Loot: ${formatRaidLoot(details.loot)}`);
  }

  return lines.join('\n');
};''',
'''  if (details.loot) {
    lines.push(`Loot: ${formatRaidLoot(details.loot)}`);
  }
  if (details.treasures && details.treasures.length > 0) {
    lines.push(`Treasure: ${details.treasures.join(', ')}`);
  }

  return lines.join('\n');
};''',
1)
resolver = resolver.replace(
'''    combat: CombatResult;
    carriedResources: RaidResourceBundle;
  },''',
'''    combat: CombatResult;
    carriedResources: RaidResourceBundle;
    collectedTreasures?: string[];
  },''',
1)
resolver = resolver.replace(
'''      combat: args.combat,
      loot: args.carriedResources,
    }),''',
'''      combat: args.combat,
      loot: args.carriedResources,
      treasures: args.collectedTreasures,
    }),''',
1)
helper_marker = "const calculateRaidCarryCapacity = (troops: GameEvent<'troopMovementRaid'>['troops']) => {"
helper = r'''
const lanArcadeNpcGrowthRowSchema = z.strictObject({
  villageId: z.number(),
  tileId: z.number(),
  playerId: z.number(),
  tribe: playableTribeSchema.or(z.literal('natars')),
  population: z.number(),
  defenderCount: z.number(),
});

const ensureLanArcadeNpcGrowthTable = (
  database: Parameters<Resolver<GameEvent<'troopMovementRaid'>>>[0],
) => {
  database.exec({
    sql: `
      CREATE TABLE IF NOT EXISTS lan_arcade_npc_growth
      (
        tile_id INTEGER PRIMARY KEY,
        last_reinforced_at INTEGER NOT NULL
      ) STRICT;
    `,
  });
};

const getLanArcadeNpcDefenceUnits = (tribe: string): [CombatTroop['unitId'], CombatTroop['unitId']] => {
  switch (tribe) {
    case 'romans':
      return ['LEGIONNAIRE', 'PRAETORIAN'];
    case 'gauls':
      return ['PHALANX', 'SWORDSMAN'];
    case 'teutons':
      return ['SPEARMAN', 'AXEMAN'];
    case 'huns':
      return ['MERCENARY', 'BOWMAN'];
    case 'egyptians':
      return ['SLAVE_MILITIA', 'KHOPESH_WARRIOR'];
    case 'natars':
      return ['PIKEMAN', 'THORNED_WARRIOR'];
    default:
      return ['PHALANX', 'SWORDSMAN'];
  }
};

export const refreshLanArcadeNpcVillage = (
  database: Parameters<Resolver<GameEvent<'troopMovementRaid'>>>[0],
  targetTileId: number,
  timestamp: number,
) => {
  ensureLanArcadeNpcGrowthTable(database);

  const target = database.selectObject({
    sql: `
      SELECT
        v.id AS villageId,
        v.tile_id AS tileId,
        p.id AS playerId,
        ti.tribe AS tribe,
        CAST(COALESCE(ROUND(SUM(CASE WHEN ei.effect = 'wheatProduction' AND e.source = 'building' THEN -e.value ELSE 0 END)), 50) AS INTEGER) AS population,
        CAST(COALESCE((
          SELECT SUM(t.amount)
          FROM troops t
          WHERE t.tile_id = v.tile_id
        ), 0) AS INTEGER) AS defenderCount
      FROM villages v
        JOIN players p ON p.id = v.player_id
        JOIN tribe_ids ti ON ti.id = p.tribe_id
        LEFT JOIN effects e ON e.village_id = v.id
        LEFT JOIN effect_ids ei ON ei.id = e.effect_id
      WHERE v.tile_id = $target_tile_id
        AND p.id != $player_id
      GROUP BY v.id, v.tile_id, p.id, ti.tribe;
    `,
    bind: { $target_tile_id: targetTileId, $player_id: PLAYER_ID },
    schema: lanArcadeNpcGrowthRowSchema,
  });

  if (!target) {
    return;
  }

  const lastReinforcedAtRow = database.selectObject({
    sql: 'SELECT last_reinforced_at AS lastReinforcedAt FROM lan_arcade_npc_growth WHERE tile_id = $tile_id;',
    bind: { $tile_id: targetTileId },
    schema: z.strictObject({ lastReinforcedAt: z.number() }),
  });
  const lastReinforcedAt = lastReinforcedAtRow?.lastReinforcedAt ?? (timestamp - 4 * 60 * 60 * 1000);

  const elapsedHours = Math.max(0, (timestamp - lastReinforcedAt) / (60 * 60 * 1000));
  if (elapsedHours < 0.5) {
    return;
  }

  const population = Math.max(25, target.population);
  const maxDefenders = Math.max(12, Math.min(500, Math.round(population * 1.75)));
  const missing = Math.max(0, maxDefenders - target.defenderCount);
  const rebuildAmount = Math.min(missing, Math.floor(elapsedHours * Math.max(2, population / 12)));

  if (rebuildAmount > 0) {
    const [primary, secondary] = getLanArcadeNpcDefenceUnits(target.tribe);
    const primaryAmount = Math.max(1, Math.ceil(rebuildAmount * 0.7));
    const secondaryAmount = Math.max(0, rebuildAmount - primaryAmount);
    addTroops(database, [
      { unitId: primary, amount: primaryAmount, tileId: targetTileId, source: targetTileId },
      ...(secondaryAmount > 0 ? [{ unitId: secondary, amount: secondaryAmount, tileId: targetTileId, source: targetTileId }] : []),
    ]);
  }

  database.exec({
    sql: `
      INSERT INTO lan_arcade_npc_growth (tile_id, last_reinforced_at)
      VALUES ($tile_id, $timestamp)
      ON CONFLICT(tile_id) DO UPDATE SET last_reinforced_at = $timestamp;
    `,
    bind: { $tile_id: targetTileId, $timestamp: timestamp },
  });
};

const hasSurvivingHero = (troops: CombatTroop[]) => {
  return troops.some(({ unitId, amount }) => unitId === 'HERO' && amount > 0);
};

const worldItemRowSchema = z.strictObject({
  itemId: z.number(),
  amount: z.number(),
});

const collectLanArcadeWorldItemsWithHero = (
  database: Parameters<Resolver<GameEvent<'troopMovementRaid'>>>[0],
  villageId: number,
  targetTileId: number,
  survivors: CombatTroop[],
) => {
  if (!hasSurvivingHero(survivors)) {
    return [];
  }

  const heroId = database.selectValue({
    sql: 'SELECT h.id FROM heroes h JOIN villages v ON v.player_id = h.player_id WHERE v.id = $village_id LIMIT 1;',
    bind: { $village_id: villageId },
    schema: z.number(),
  });

  if (!heroId) {
    return [];
  }

  const items = database.selectObjects({
    sql: 'SELECT item_id AS itemId, amount FROM world_items WHERE tile_id = $tile_id;',
    bind: { $tile_id: targetTileId },
    schema: worldItemRowSchema,
  });

  if (items.length === 0) {
    return [];
  }

  for (const item of items) {
    database.exec({
      sql: `
        INSERT INTO hero_inventory (hero_id, item_id, amount)
        VALUES ($hero_id, $item_id, $amount)
        ON CONFLICT(hero_id, item_id) DO UPDATE SET amount = amount + EXCLUDED.amount;
      `,
      bind: { $hero_id: heroId, $item_id: item.itemId, $amount: item.amount },
    });
  }

  database.exec({
    sql: 'DELETE FROM world_items WHERE tile_id = $tile_id;',
    bind: { $tile_id: targetTileId },
  });

  return items.map((item) => {
    const definition = getItemDefinition(item.itemId);
    const label = definition?.name ? definition.name.replaceAll('_', ' ') : `item ${item.itemId}`;
    return `${item.amount} ${label}`;
  });
};

'''
if 'const refreshLanArcadeNpcVillage' not in resolver:
    if helper_marker not in resolver:
        raise SystemExit('raid carry marker not found for phase3 helper insertion')
    resolver = resolver.replace(helper_marker, helper + helper_marker, 1)
# Refresh NPC villages before scout/attack/raid defender selection.
resolver = resolver.replace(
'''  const target = selectTargetIdentity(database, targetTileId);
  const defenders = selectDefendersAtTile(database, targetTileId);

  if (isLanArcadeScoutOnlyMovement(troops)) {''',
'''  refreshLanArcadeNpcVillage(database, targetTileId, resolvesAt);
  const target = selectTargetIdentity(database, targetTileId);
  const defenders = selectDefendersAtTile(database, targetTileId);

  if (isLanArcadeScoutOnlyMovement(troops)) {''',
1)
resolver = resolver.replace(
'''  const target = selectTargetIdentity(database, targetTileId);
  const defenders = selectDefendersAtTile(database, targetTileId);

  if (isLanArcadeScoutOnlyMovement(troops)) {''',
'''  refreshLanArcadeNpcVillage(database, targetTileId, resolvesAt);
  const target = selectTargetIdentity(database, targetTileId);
  const defenders = selectDefendersAtTile(database, targetTileId);

  if (isLanArcadeScoutOnlyMovement(troops)) {''',
1)
resolver = resolver.replace(
'''  const carriedResources = raidVillageResources(
    database,
    targetTileId,
    resolvesAt,
    calculateRaidCarryCapacity(combat.attackerSurvivors),
  );

  createLanArcadeRaidReport(database, {
''',
'''  const carriedResources = raidVillageResources(
    database,
    targetTileId,
    resolvesAt,
    calculateRaidCarryCapacity(combat.attackerSurvivors),
  );
  const collectedTreasures = collectLanArcadeWorldItemsWithHero(
    database,
    villageId,
    targetTileId,
    combat.attackerSurvivors,
  );

  createLanArcadeRaidReport(database, {
''',
1)
resolver = resolver.replace(
'''    combat,
    carriedResources,
  });
''',
'''    combat,
    carriedResources,
    collectedTreasures,
  });
''',
1)
resolver = resolver.replace(
'''      defenderLosses: combat.defenderLosses,
    } as never);''',
'''      defenderLosses: combat.defenderLosses,
      collectedTreasures,
    } as never);''',
1)
resolver_path.write_text(resolver)

# Make tooltip wording a little clearer now that hero collection is implemented.
tile_tooltip_path = root / 'apps/web/app/(game)/(village-slug)/(map)/components/tile-tooltip.tsx'
tile_tooltip = tile_tooltip_path.read_text()
tile_tooltip = tile_tooltip.replace(
    'Send a surviving Hero raid to collect treasure.',
    'Send a Hero raid; if the hero survives, this treasure is added to inventory.',
)
tile_tooltip_path.write_text(tile_tooltip)
PY

# LAN Arcade phase upgrade patch 2026-06-22 phase 3 fixes: final-source cleanup after NPC/treasure patch.
python3 - <<'PY'
from pathlib import Path
root = Path('.')
resolver_path = root / 'packages/api/src/http/events/resolvers/troop-movement-resolver.ts'
resolver = resolver_path.read_text()
# Ensure attack and raid both refresh NPC targets before selecting defenders.
resolver = resolver.replace(
'''  const { id, villageId, resolvesAt, originTileId, targetTileId, troops } = args;
  const target = selectTargetIdentity(database, targetTileId);''',
'''  const { id, villageId, resolvesAt, originTileId, targetTileId, troops } = args;
  refreshLanArcadeNpcVillage(database, targetTileId, resolvesAt);
  const target = selectTargetIdentity(database, targetTileId);''',
1)
resolver = resolver.replace(
'''  const { id, villageId, resolvesAt, troops, originTileId, targetTileId } = args;
  const target = selectTargetIdentity(database, targetTileId);''',
'''  const { id, villageId, resolvesAt, troops, originTileId, targetTileId } = args;
  refreshLanArcadeNpcVillage(database, targetTileId, resolvesAt);
  const target = selectTargetIdentity(database, targetTileId);''',
1)
# A broad earlier replacement may have leaked collectedTreasures into attack return metadata; remove it before the raid resolver.
raid_index = resolver.find("export const raidMovementResolver")
if raid_index != -1:
    before_raid = resolver[:raid_index].replace("      defenderLosses: combat.defenderLosses,\n      collectedTreasures,", "      defenderLosses: combat.defenderLosses,")
    resolver = before_raid + resolver[raid_index:]
# Add treasure rendering to the final report describer shape.
resolver = resolver.replace(
'''  loot?: RaidResourceBundle;
}) => {''',
'''  loot?: RaidResourceBundle;
  treasures?: string[];
}) => {''',
1)
resolver = resolver.replace(
'''  if (args.loot) {
    parts.push(`Loot: ${formatRaidLoot(args.loot)}.`);
  }

  parts.push(''',
'''  if (args.loot) {
    parts.push(`Loot: ${formatRaidLoot(args.loot)}.`);
  }
  if (args.treasures && args.treasures.length > 0) {
    parts.push(`Treasure: ${args.treasures.join(', ')}.`);
  }

  parts.push(''',
1)
if 'refreshLanArcadeNpcVillage(database, targetTileId, resolvesAt);' not in resolver:
    raise SystemExit('NPC refresh call missing after phase3 final-source cleanup')
if 'Treasure: ${args.treasures.join' not in resolver:
    raise SystemExit('Treasure report rendering missing after phase3 final-source cleanup')
resolver_path.write_text(resolver)
PY


# LAN Arcade phase upgrade patch 2026-06-22 phase 3b: resource-first NPC development and regional skirmishes.
echo "Applying LAN Arcade phase upgrade patch 2026-06-22 phase 3b..."
python3 - <<'PY'
from pathlib import Path

root = Path('.')
resolver_path = root / 'packages/api/src/http/events/resolvers/troop-movement-resolver.ts'
resolver = resolver_path.read_text()

if "@pillage-first/game-assets/utils/buildings" not in resolver:
    resolver = resolver.replace(
        "import { getItemDefinition } from '@pillage-first/game-assets/utils/items';",
        "import { getItemDefinition } from '@pillage-first/game-assets/utils/items';\nimport {\n  calculatePopulationDifference,\n  getBuildingDefinition,\n} from '@pillage-first/game-assets/utils/buildings';",
        1,
    )

before_effect_import = resolver.split("from '../../../queries/effect-queries';", 1)[0]
if "updateBuildingEffectQuery" not in before_effect_import:
    resolver = resolver.replace(
        "  insertEffectByEffectNameQuery,\n  insertEffectQuery,\n  selectWheatProductionEffectIdQuery,",
        "  insertEffectByEffectNameQuery,\n  insertEffectQuery,\n  selectWheatProductionEffectIdQuery,\n  updateBuildingEffectQuery,\n  updatePopulationEffectQuery,",
        1,
    )

start = resolver.find('const lanArcadeNpcGrowthRowSchema = z.strictObject({')
end = resolver.find('const hasSurvivingHero = (troops: CombatTroop[]) => {')
if start == -1 or end == -1:
    raise SystemExit('NPC growth helper block not found')

helper = r'''const lanArcadeNpcGrowthRowSchema = z.strictObject({
  villageId: z.number(),
  tileId: z.number(),
  playerId: z.number(),
  tribe: playableTribeSchema.or(z.literal('natars')),
  population: z.number(),
  defenderCount: z.number(),
});

const lanArcadeNpcGrowthStateSchema = z.strictObject({
  lastReinforcedAt: z.number(),
  lastDevelopedAt: z.number().nullable(),
  lastConflictAt: z.number().nullable(),
  resourceUpgradeStreak: z.number().nullable(),
});

const lanArcadeNpcBuildingRowSchema = z.strictObject({
  fieldId: z.number(),
  buildingId: buildingIdSchema,
  level: z.number(),
});

const lanArcadeNpcRivalRowSchema = z.strictObject({
  villageId: z.number(),
  tileId: z.number(),
  population: z.number(),
  defenderCount: z.number(),
});

const lanArcadeNpcTroopRowSchema = z.strictObject({
  unitId: unitIdSchema,
  amount: z.number(),
});

const ensureLanArcadeNpcGrowthTable = (
  database: Parameters<Resolver<GameEvent<'troopMovementRaid'>>>[0],
) => {
  database.exec({
    sql: `
      CREATE TABLE IF NOT EXISTS lan_arcade_npc_growth
      (
        tile_id INTEGER PRIMARY KEY,
        last_reinforced_at INTEGER NOT NULL,
        last_developed_at INTEGER,
        last_conflict_at INTEGER,
        resource_upgrade_streak INTEGER NOT NULL DEFAULT 0
      ) STRICT;
    `,
  });

  try {
    database.exec({ sql: 'ALTER TABLE lan_arcade_npc_growth ADD COLUMN last_developed_at INTEGER;' });
  } catch {
    // Existing LAN saves may already have this column.
  }
  try {
    database.exec({ sql: 'ALTER TABLE lan_arcade_npc_growth ADD COLUMN last_conflict_at INTEGER;' });
  } catch {
    // Existing LAN saves may already have this column.
  }
  try {
    database.exec({ sql: 'ALTER TABLE lan_arcade_npc_growth ADD COLUMN resource_upgrade_streak INTEGER NOT NULL DEFAULT 0;' });
  } catch {
    // Existing LAN saves may already have this column.
  }
};

const getLanArcadeNpcDefenceUnits = (tribe: string): [CombatTroop['unitId'], CombatTroop['unitId']] => {
  switch (tribe) {
    case 'romans':
      return ['LEGIONNAIRE', 'PRAETORIAN'];
    case 'gauls':
      return ['PHALANX', 'SWORDSMAN'];
    case 'teutons':
      return ['SPEARMAN', 'AXEMAN'];
    case 'huns':
      return ['MERCENARY', 'BOWMAN'];
    case 'egyptians':
      return ['SLAVE_MILITIA', 'KHOPESH_WARRIOR'];
    case 'natars':
      return ['PIKEMAN', 'THORNED_WARRIOR'];
    default:
      return ['PHALANX', 'SWORDSMAN'];
  }
};

const selectLanArcadeNpcPopulation = (
  database: Parameters<Resolver<GameEvent<'troopMovementRaid'>>>[0],
  villageId: number,
) => database.selectValue({
  sql: `
    SELECT CAST(COALESCE(ROUND(SUM(CASE WHEN ei.effect = 'wheatProduction' AND e.source = 'building' THEN -e.value ELSE 0 END)), 50) AS INTEGER)
    FROM effects e
      JOIN effect_ids ei ON ei.id = e.effect_id
    WHERE e.village_id = $village_id;
  `,
  bind: { $village_id: villageId },
  schema: z.number(),
}) ?? 50;

const selectLanArcadeNpcDefenderCount = (
  database: Parameters<Resolver<GameEvent<'troopMovementRaid'>>>[0],
  tileId: number,
) => database.selectValue({
  sql: 'SELECT CAST(COALESCE(SUM(amount), 0) AS INTEGER) FROM troops WHERE tile_id = $tile_id;',
  bind: { $tile_id: tileId },
  schema: z.number(),
}) ?? 0;

const getLanArcadeNpcDevelopmentPriority = (row: z.infer<typeof lanArcadeNpcBuildingRowSchema>) => {
  const building = getBuildingDefinition(row.buildingId);

  if (building.category === 'resource-production') {
    return 0;
  }
  if (row.buildingId === 'WAREHOUSE' || row.buildingId === 'GRANARY') {
    return 1;
  }
  if (building.category === 'resource-booster') {
    return 2;
  }
  if (row.buildingId === 'MAIN_BUILDING') {
    return 3;
  }
  if (row.buildingId === 'RALLY_POINT' || row.buildingId.endsWith('_WALL')) {
    return 4;
  }
  if (['BARRACKS', 'STABLE', 'ACADEMY', 'SMITHY'].includes(row.buildingId)) {
    return 5;
  }

  return building.category === 'military' ? 7 : 6;
};

const getLanArcadeNpcDevelopmentCap = (
  row: z.infer<typeof lanArcadeNpcBuildingRowSchema>,
  population: number,
) => {
  const building = getBuildingDefinition(row.buildingId);
  const economyCap = Math.min(20, Math.max(4, Math.floor(Math.sqrt(Math.max(25, population))) + 2));

  if (building.category === 'resource-production') {
    return Math.min(building.maxLevel, economyCap);
  }
  if (row.buildingId === 'WAREHOUSE' || row.buildingId === 'GRANARY') {
    return Math.min(building.maxLevel, Math.max(3, economyCap - 1));
  }
  if (building.category === 'resource-booster') {
    return Math.min(building.maxLevel, Math.max(1, Math.floor((economyCap - 5) / 2)));
  }
  if (row.buildingId === 'MAIN_BUILDING') {
    return Math.min(building.maxLevel, Math.max(3, Math.floor(economyCap / 2)));
  }

  // Keep NPC economy ahead of army infrastructure. Defenders still recover from population.
  return Math.min(building.maxLevel, Math.max(1, Math.floor(economyCap / 3)));
};

const upgradeLanArcadeNpcBuilding = (
  database: Parameters<Resolver<GameEvent<'troopMovementRaid'>>>[0],
  villageId: number,
  row: z.infer<typeof lanArcadeNpcBuildingRowSchema>,
  nextLevel: number,
) => {
  database.exec({
    sql: `
      UPDATE building_fields
      SET level = $level
      WHERE village_id = $village_id
        AND field_id = $field_id;
    `,
    bind: {
      $village_id: villageId,
      $field_id: row.fieldId,
      $level: nextLevel,
    },
  });

  const populationDifference = calculatePopulationDifference(row.buildingId, row.level, nextLevel);
  if (populationDifference !== 0) {
    database.exec({
      sql: updatePopulationEffectQuery,
      bind: {
        $village_id: villageId,
        $value: populationDifference,
      },
    });
  }

  const { effects } = getBuildingDefinition(row.buildingId);
  for (const { effectId, valuesPerLevel, type } of effects) {
    database.exec({
      sql: updateBuildingEffectQuery,
      bind: {
        $effect_id: effectId,
        $value: valuesPerLevel[nextLevel],
        $type: type,
        $village_id: villageId,
        $source_specifier: row.fieldId,
      },
    });
  }
};

const developLanArcadeNpcVillage = (
  database: Parameters<Resolver<GameEvent<'troopMovementRaid'>>>[0],
  target: z.infer<typeof lanArcadeNpcGrowthRowSchema>,
  timestamp: number,
  elapsedHours: number,
  resourceUpgradeStreak: number,
) => {
  const growthHoursPerUpgrade = Math.min(12, Math.max(0.75, Math.sqrt(Math.max(25, target.population)) / 10));
  const upgradeBudget = Math.min(10, Math.floor(elapsedHours / growthHoursPerUpgrade));
  if (upgradeBudget <= 0) {
    return { upgradesApplied: 0, population: target.population, resourceUpgradeStreak };
  }

  updateVillageResourcesAt(database, target.villageId, timestamp);

  const buildingRows = database.selectObjects({
    sql: `
      SELECT
        bf.field_id AS fieldId,
        bi.building AS buildingId,
        bf.level AS level
      FROM building_fields bf
        JOIN building_ids bi ON bi.id = bf.building_id
      WHERE bf.village_id = $village_id;
    `,
    bind: { $village_id: target.villageId },
    schema: lanArcadeNpcBuildingRowSchema,
  });

  const candidates = buildingRows
    .filter((row) => row.level < getLanArcadeNpcDevelopmentCap(row, target.population))
    .sort((a, b) => (
      getLanArcadeNpcDevelopmentPriority(a) - getLanArcadeNpcDevelopmentPriority(b)
      || a.level - b.level
      || a.fieldId - b.fieldId
    ));
  const resourceCandidates = candidates.filter((row) => getBuildingDefinition(row.buildingId).category === 'resource-production');
  const storageCandidates = candidates.filter((row) => row.buildingId === 'WAREHOUSE' || row.buildingId === 'GRANARY');
  const otherCandidates = candidates.filter((row) => (
    getBuildingDefinition(row.buildingId).category !== 'resource-production'
    && row.buildingId !== 'WAREHOUSE'
    && row.buildingId !== 'GRANARY'
  ));

  let upgradesApplied = 0;
  let currentResourceUpgradeStreak = resourceUpgradeStreak;
  const selectedRows: z.infer<typeof lanArcadeNpcBuildingRowSchema>[] = [];
  while (selectedRows.length < upgradeBudget) {
    const shouldUpgradeStorage = currentResourceUpgradeStreak >= 3 && storageCandidates.length > 0;
    const row = shouldUpgradeStorage
      ? storageCandidates.shift()
      : (resourceCandidates.shift() ?? storageCandidates.shift() ?? otherCandidates.shift());
    if (!row) {
      break;
    }
    selectedRows.push(row);
    if (row.buildingId === 'WAREHOUSE' || row.buildingId === 'GRANARY') {
      currentResourceUpgradeStreak = 0;
    } else if (getBuildingDefinition(row.buildingId).category === 'resource-production') {
      currentResourceUpgradeStreak += 1;
    }
  }

  for (const row of selectedRows) {
    upgradeLanArcadeNpcBuilding(database, target.villageId, row, row.level + 1);
    upgradesApplied += 1;
  }

  if (upgradesApplied > 0) {
    // Newly developed farms should not feel empty immediately after storage/production catches up.
    const reserve = Math.floor(Math.max(200, Math.min(2500, target.population * 4)) * upgradesApplied);
    addVillageResourcesAt(database, target.villageId, timestamp, [reserve, reserve, reserve, reserve]);
  }

  updateVillageResourcesAt(database, target.villageId, timestamp);

  return {
    upgradesApplied,
    population: selectLanArcadeNpcPopulation(database, target.villageId),
    resourceUpgradeStreak: currentResourceUpgradeStreak,
  };
};

const removeLanArcadeNpcDefenders = (
  database: Parameters<Resolver<GameEvent<'troopMovementRaid'>>>[0],
  tileId: number,
  losses: number,
) => {
  let remainingLosses = Math.max(0, Math.floor(losses));
  if (remainingLosses <= 0) {
    return;
  }

  const troops = database.selectObjects({
    sql: `
      SELECT ui.unit AS unitId, t.amount AS amount
      FROM troops t
        JOIN unit_ids ui ON ui.id = t.unit_id
      WHERE t.tile_id = $tile_id
        AND t.source_tile_id = $tile_id
      ORDER BY t.amount DESC;
    `,
    bind: { $tile_id: tileId },
    schema: lanArcadeNpcTroopRowSchema,
  });

  for (const troop of troops) {
    if (remainingLosses <= 0) {
      return;
    }
    const amount = Math.min(troop.amount, remainingLosses);
    removeTroops(database, [{ unitId: troop.unitId, amount, tileId, source: tileId }]);
    remainingLosses -= amount;
  }
};

const simulateLanArcadeNpcRegionalConflict = (
  database: Parameters<Resolver<GameEvent<'troopMovementRaid'>>>[0],
  target: z.infer<typeof lanArcadeNpcGrowthRowSchema>,
  population: number,
  timestamp: number,
  elapsedHours: number,
) => {
  const conflictRounds = Math.min(3, Math.floor(elapsedHours / 4));
  if (conflictRounds <= 0) {
    return false;
  }

  const rival = database.selectObject({
    sql: `
      SELECT
        rv.id AS villageId,
        rv.tile_id AS tileId,
        CAST(COALESCE(ROUND(SUM(CASE WHEN ei.effect = 'wheatProduction' AND e.source = 'building' THEN -e.value ELSE 0 END)), 50) AS INTEGER) AS population,
        CAST(COALESCE((
          SELECT SUM(t.amount)
          FROM troops t
          WHERE t.tile_id = rv.tile_id
        ), 0) AS INTEGER) AS defenderCount
      FROM villages cv
        JOIN tiles ct ON ct.id = cv.tile_id
        JOIN tiles rt ON ABS(rt.x - ct.x) + ABS(rt.y - ct.y) BETWEEN 1 AND 8
        JOIN villages rv ON rv.tile_id = rt.id
        JOIN players rp ON rp.id = rv.player_id
        LEFT JOIN effects e ON e.village_id = rv.id
        LEFT JOIN effect_ids ei ON ei.id = e.effect_id
      WHERE cv.id = $village_id
        AND rv.id != cv.id
        AND rp.id != $player_id
      GROUP BY rv.id, rv.tile_id
      ORDER BY ABS(rt.x - ct.x) + ABS(rt.y - ct.y), rv.id
      LIMIT 1;
    `,
    bind: { $village_id: target.villageId, $player_id: PLAYER_ID },
    schema: lanArcadeNpcRivalRowSchema,
  });

  if (!rival) {
    return false;
  }

  updateVillageResourcesAt(database, target.villageId, timestamp);
  updateVillageResourcesAt(database, rival.villageId, timestamp);

  const currentDefenders = selectLanArcadeNpcDefenderCount(database, target.tileId);
  const rivalDefenders = selectLanArcadeNpcDefenderCount(database, rival.tileId);
  const seed = ((target.tileId * 31 + rival.tileId * 17 + Math.floor(timestamp / (60 * 60 * 1000))) % 100) / 100;
  const ownPower = currentDefenders + population * (0.22 + seed * 0.08);
  const rivalPower = rivalDefenders + rival.population * (0.26 - seed * 0.08);
  const losses = Math.max(1, Math.floor(Math.min(currentDefenders || 1, rivalDefenders || 1) * 0.025 * conflictRounds));
  const raidPressure = Math.floor(Math.max(100, Math.min(1800, Math.max(population, rival.population) * 3)) * conflictRounds);

  if (ownPower >= rivalPower) {
    removeLanArcadeNpcDefenders(database, rival.tileId, losses);
    subtractVillageResourcesAt(database, rival.villageId, timestamp, [raidPressure, raidPressure, raidPressure, raidPressure]);
    addVillageResourcesAt(database, target.villageId, timestamp, [raidPressure, raidPressure, raidPressure, raidPressure]);
  } else {
    removeLanArcadeNpcDefenders(database, target.tileId, losses);
    subtractVillageResourcesAt(database, target.villageId, timestamp, [raidPressure, raidPressure, raidPressure, raidPressure]);
    addVillageResourcesAt(database, rival.villageId, timestamp, [raidPressure, raidPressure, raidPressure, raidPressure]);
  }

  return true;
};

export const refreshLanArcadeNpcVillage = (
  database: Parameters<Resolver<GameEvent<'troopMovementRaid'>>>[0],
  targetTileId: number,
  timestamp: number,
) => {
  ensureLanArcadeNpcGrowthTable(database);

  const target = database.selectObject({
    sql: `
      SELECT
        v.id AS villageId,
        v.tile_id AS tileId,
        p.id AS playerId,
        ti.tribe AS tribe,
        CAST(COALESCE(ROUND(SUM(CASE WHEN ei.effect = 'wheatProduction' AND e.source = 'building' THEN -e.value ELSE 0 END)), 50) AS INTEGER) AS population,
        CAST(COALESCE((
          SELECT SUM(t.amount)
          FROM troops t
          WHERE t.tile_id = v.tile_id
        ), 0) AS INTEGER) AS defenderCount
      FROM villages v
        JOIN players p ON p.id = v.player_id
        JOIN tribe_ids ti ON ti.id = p.tribe_id
        LEFT JOIN effects e ON e.village_id = v.id
        LEFT JOIN effect_ids ei ON ei.id = e.effect_id
      WHERE v.tile_id = $target_tile_id
        AND p.id != $player_id
      GROUP BY v.id, v.tile_id, p.id, ti.tribe;
    `,
    bind: { $target_tile_id: targetTileId, $player_id: PLAYER_ID },
    schema: lanArcadeNpcGrowthRowSchema,
  });

  if (!target) {
    return;
  }

  const growthState = database.selectObject({
    sql: `
      SELECT
        last_reinforced_at AS lastReinforcedAt,
        last_developed_at AS lastDevelopedAt,
        last_conflict_at AS lastConflictAt,
        resource_upgrade_streak AS resourceUpgradeStreak
      FROM lan_arcade_npc_growth
      WHERE tile_id = $tile_id;
    `,
    bind: { $tile_id: targetTileId },
    schema: lanArcadeNpcGrowthStateSchema,
  });
  const defaultPast = timestamp - 8 * 60 * 60 * 1000;
  const lastReinforcedAt = growthState?.lastReinforcedAt ?? (timestamp - 4 * 60 * 60 * 1000);
  const lastDevelopedAt = growthState ? (growthState.lastDevelopedAt ?? growthState.lastReinforcedAt) : defaultPast;
  const lastConflictAt = growthState ? (growthState.lastConflictAt ?? growthState.lastReinforcedAt) : defaultPast;
  const resourceUpgradeStreak = growthState?.resourceUpgradeStreak ?? 0;

  updateVillageResourcesAt(database, target.villageId, timestamp);

  const developmentElapsedHours = Math.max(0, (timestamp - lastDevelopedAt) / (60 * 60 * 1000));
  const { upgradesApplied, population, resourceUpgradeStreak: nextResourceUpgradeStreak } = developLanArcadeNpcVillage(
    database,
    target,
    timestamp,
    developmentElapsedHours,
    resourceUpgradeStreak,
  );

  const reinforcementElapsedHours = Math.max(0, (timestamp - lastReinforcedAt) / (60 * 60 * 1000));
  const currentDefenderCount = selectLanArcadeNpcDefenderCount(database, targetTileId);
  const populationForDefence = Math.max(25, population);
  const farmGuardCap = Math.max(6, Math.min(18, Math.round(Math.sqrt(populationForDefence) * 1.8)));
  const standingArmyCap = Math.max(farmGuardCap, Math.min(420, Math.round(populationForDefence * 0.9)));
  const localGuardMissing = Math.max(0, farmGuardCap - currentDefenderCount);
  const standingArmyMissing = Math.max(0, standingArmyCap - Math.max(currentDefenderCount, farmGuardCap));
  const guardRebuild = reinforcementElapsedHours < 1
    ? 0
    : Math.min(localGuardMissing, Math.floor(reinforcementElapsedHours * Math.max(0.5, populationForDefence / 90)));
  const reserveRebuild = localGuardMissing > 0 || reinforcementElapsedHours < 8
    ? 0
    : Math.min(standingArmyMissing, Math.floor(reinforcementElapsedHours / 8));
  const rebuildAmount = guardRebuild + reserveRebuild;

  if (rebuildAmount > 0) {
    const [primary, secondary] = getLanArcadeNpcDefenceUnits(target.tribe);
    const primaryAmount = Math.max(1, Math.ceil(rebuildAmount * 0.7));
    const secondaryAmount = Math.max(0, rebuildAmount - primaryAmount);
    addTroops(database, [
      { unitId: primary, amount: primaryAmount, tileId: targetTileId, source: targetTileId },
      ...(secondaryAmount > 0 ? [{ unitId: secondary, amount: secondaryAmount, tileId: targetTileId, source: targetTileId }] : []),
    ]);
  }

  const conflictElapsedHours = Math.max(0, (timestamp - lastConflictAt) / (60 * 60 * 1000));
  const conflictApplied = simulateLanArcadeNpcRegionalConflict(database, target, population, timestamp, conflictElapsedHours);

  database.exec({
    sql: `
      INSERT INTO lan_arcade_npc_growth (tile_id, last_reinforced_at, last_developed_at, last_conflict_at, resource_upgrade_streak)
      VALUES ($tile_id, $last_reinforced_at, $last_developed_at, $last_conflict_at, $resource_upgrade_streak)
      ON CONFLICT(tile_id) DO UPDATE SET
        last_reinforced_at = $last_reinforced_at,
        last_developed_at = COALESCE($last_developed_at, lan_arcade_npc_growth.last_developed_at),
        last_conflict_at = COALESCE($last_conflict_at, lan_arcade_npc_growth.last_conflict_at),
        resource_upgrade_streak = $resource_upgrade_streak;
    `,
    bind: {
      $tile_id: targetTileId,
      $last_reinforced_at: rebuildAmount > 0 ? timestamp : lastReinforcedAt,
      $last_developed_at: upgradesApplied > 0 ? timestamp : null,
      $last_conflict_at: conflictApplied ? timestamp : null,
      $resource_upgrade_streak: nextResourceUpgradeStreak,
    },
  });
};

export const refreshLanArcadeNpcVillagesForMap = (
  database: Parameters<Resolver<GameEvent<'troopMovementRaid'>>>[0],
  timestamp: number,
) => {
  ensureLanArcadeNpcGrowthTable(database);

  const developmentCutoff = timestamp - 45 * 60 * 1000;
  const reinforcementCutoff = timestamp - 45 * 60 * 1000;
  const targetTileIds = database.selectObjects({
    sql: `
      SELECT v.tile_id AS tileId
      FROM villages v
        JOIN players p ON p.id = v.player_id
        JOIN tiles target_tile ON target_tile.id = v.tile_id
        JOIN villages player_village ON player_village.player_id = $player_id
        JOIN tiles player_tile ON player_tile.id = player_village.tile_id
        LEFT JOIN lan_arcade_npc_growth g ON g.tile_id = v.tile_id
      WHERE p.id != $player_id
        AND ABS(target_tile.x - player_tile.x) <= 12
        AND ABS(target_tile.y - player_tile.y) <= 12
        AND (
          g.tile_id IS NULL
          OR g.last_developed_at IS NULL
          OR g.last_developed_at <= $development_cutoff
          OR g.last_reinforced_at <= $reinforcement_cutoff
        )
      GROUP BY v.tile_id
      ORDER BY
        CASE WHEN g.tile_id IS NULL THEN 0 ELSE 1 END,
        MIN(ABS(target_tile.x - player_tile.x) + ABS(target_tile.y - player_tile.y)),
        COALESCE(g.last_developed_at, 0),
        v.id
      LIMIT 12;
    `,
    bind: {
      $player_id: PLAYER_ID,
      $development_cutoff: developmentCutoff,
      $reinforcement_cutoff: reinforcementCutoff,
    },
    schema: z.strictObject({ tileId: z.number() }),
  });

  for (const { tileId } of targetTileIds) {
    refreshLanArcadeNpcVillage(database, tileId, timestamp);
  }
};

'''
resolver = resolver[:start] + helper + resolver[end:]
resolver = resolver.replace(
    '  refreshLanArcadeNpcVillage(database, targetTileId, resolvesAt);\n  refreshLanArcadeNpcVillage(database, targetTileId, resolvesAt);',
    '  refreshLanArcadeNpcVillage(database, targetTileId, resolvesAt);'
)
if "last_developed_at" not in resolver or "simulateLanArcadeNpcRegionalConflict" not in resolver:
    raise SystemExit('phase 3b NPC development patch did not apply')
resolver_path.write_text(resolver)
PY


# LAN Arcade phase upgrade patch 2026-06-24 phase 3c: map-load NPC catch-up.
echo "Applying LAN Arcade phase upgrade patch 2026-06-24 phase 3c..."
python3 - <<'PY'
from pathlib import Path

root = Path('.')
controller_path = root / 'packages/api/src/http/controllers/map-controllers.ts'
controller = controller_path.read_text()

import_line = "import { refreshLanArcadeNpcVillagesForMap } from '../events/resolvers/troop-movement-resolver';\n"
if import_line not in controller:
    marker = "import { selectServerMapSizeQuery } from '../../queries/server-queries';\n"
    if marker not in controller:
        raise SystemExit('map controller server-query import marker not found')
    controller = controller.replace(marker, marker + import_line, 1)

old = ")(({ database }) => {\n  const parsedTiles = database.selectObjects({"
new = ")(({ database }) => {\n  refreshLanArcadeNpcVillagesForMap(database, Date.now());\n\n  const parsedTiles = database.selectObjects({"
if new not in controller:
    if old not in controller:
        raise SystemExit('map controller getTiles body marker not found')
    controller = controller.replace(old, new, 1)

controller_path.write_text(controller)

resolver_path = root / 'packages/api/src/http/events/resolvers/troop-movement-resolver.ts'
resolver = resolver_path.read_text()
required = [
    'export const refreshLanArcadeNpcVillage',
    'export const refreshLanArcadeNpcVillagesForMap',
    'growthHoursPerUpgrade',
]
missing = [item for item in required if item not in resolver]
if missing:
    raise SystemExit(f'map NPC catch-up resolver markers missing: {missing}')
PY

# LAN Arcade phase upgrade patch 2026-06-22 phase 4: map movement visibility and travel help.
echo "Applying LAN Arcade phase upgrade patch 2026-06-22 phase 4..."
python3 <<'PY'
from pathlib import Path

root = Path.cwd()

def replace_once(path, old, new):
    p = root / path
    text = p.read_text()
    if new in text:
        return
    if old not in text:
        raise SystemExit(f'pattern not found in {path}: {old[:120]!r}')
    p.write_text(text.replace(old, new, 1))

schema_path = 'packages/api/src/http/controllers/schemas/troop-movement-schemas.ts'
replace_once(
    schema_path,
    "    originating_tile_id: z.number(),\n    player_id: z.number(),",
    "    originating_tile_id: z.number(),\n    originating_x: z.number(),\n    originating_y: z.number(),\n    player_id: z.number(),",
)
replace_once(
    schema_path,
    "    target_tile_id: z.number().nullable(),\n  })",
    "    target_tile_id: z.number().nullable(),\n    target_x: z.number().nullable(),\n    target_y: z.number().nullable(),\n  })",
)

query_path = 'packages/api/src/queries/event-queries.ts'
replace_once(
    query_path,
    "    t_orig.id AS originating_tile_id,\n    p_orig.id AS player_id,",
    "    t_orig.id AS originating_tile_id,\n    t_orig.x AS originating_x,\n    t_orig.y AS originating_y,\n    p_orig.id AS player_id,",
)
replace_once(
    query_path,
    "    v_target.id AS target_village_id,\n    v_target.name AS target_village_name,\n    t_target.id AS target_tile_id",
    "    v_target.id AS target_village_id,\n    v_target.name AS target_village_name,\n    t_target.id AS target_tile_id,\n    t_target.x AS target_x,\n    t_target.y AS target_y",
)

mapper_path = 'packages/api/src/http/controllers/mappers/troop-movement-mapper.ts'
replace_once(
    mapper_path,
    "    originatingTileId: row.originating_tile_id,\n    playerName: row.player_name,",
    "    originatingTileId: row.originating_tile_id,\n    originatingX: row.originating_x,\n    originatingY: row.originating_y,\n    playerName: row.player_name,",
)
replace_once(
    mapper_path,
    "          targetVillageName: row.target_village_name,\n          targetTileId: row.target_tile_id,",
    "          targetVillageName: row.target_village_name,\n          targetTileId: row.target_tile_id,\n          targetX: row.target_x,\n          targetY: row.target_y,",
)

dto_path = 'packages/types/src/dtos/troop-movement.ts'
replace_once(
    dto_path,
    "      originatingTileId: z.number(),\n      playerName: z.string(),",
    "      originatingTileId: z.number(),\n      originatingX: z.number(),\n      originatingY: z.number(),\n      playerName: z.string(),",
)
replace_once(
    dto_path,
    "      originatingTileId: z.number(),\n      playerName: z.string(),\n      playerId: z.number(),\n      playerTribe: tribeSchema,\n      resolvesAt: z.number(),\n      targetVillageId: z.number().nullable(),",
    "      originatingTileId: z.number(),\n      originatingX: z.number(),\n      originatingY: z.number(),\n      playerName: z.string(),\n      playerId: z.number(),\n      playerTribe: tribeSchema,\n      resolvesAt: z.number(),\n      targetVillageId: z.number().nullable(),",
)
replace_once(
    dto_path,
    "      targetVillageName: z.string().nullable(),\n      targetTileId: z.number().nullable(),",
    "      targetVillageName: z.string().nullable(),\n      targetTileId: z.number().nullable(),\n      targetX: z.number().nullable(),\n      targetY: z.number().nullable(),",
)

component_path = root / 'apps/web/app/(game)/(village-slug)/(map)/components/map-active-movements.tsx'
component_path.write_text("""import { useMemo } from 'react';
import { Link } from 'react-router';
import { Countdown } from 'app/(game)/(village-slug)/components/countdown';
import { useCurrentVillage } from 'app/(game)/(village-slug)/hooks/current-village/use-current-village';
import { useVillageTroopMovements } from 'app/(game)/(village-slug)/hooks/use-village-troop-movements';

type Movement = ReturnType<typeof useVillageTroopMovements>['troopMovements'][number];

const movementLabels: Record<Movement['type'], string> = {
  troopMovementAdventure: 'Adventure',
  troopMovementAttack: 'Attack',
  troopMovementFindNewVillage: 'Settlers',
  troopMovementOasisOccupation: 'Oasis',
  troopMovementRaid: 'Raid',
  troopMovementReinforcements: 'Reinforce',
  troopMovementRelocation: 'Relocate',
  troopMovementReturn: 'Return',
};

const offensiveTypes = new Set<Movement['type']>([
  'troopMovementAttack',
  'troopMovementRaid',
  'troopMovementOasisOccupation',
]);

const formatCoords = (x: number | null | undefined, y: number | null | undefined) => {
  if (typeof x !== 'number' || typeof y !== 'number') {
    return null;
  }

  return `(${x}|${y})`;
};

const getMovementDirection = (movement: Movement, currentVillageId: number) => {
  if (movement.type === 'troopMovementReturn') {
    return 'Returning';
  }

  return movement.originatingVillageId === currentVillageId ? 'Outgoing' : 'Incoming';
};

const getMovementTarget = (movement: Movement) => {
  if (movement.type === 'troopMovementAdventure') {
    return 'Adventure site';
  }

  const coords = formatCoords(movement.targetX, movement.targetY);
  const name = movement.targetVillageName ?? 'map tile';

  return coords ? `${name} ${coords}` : name;
};

export const MapActiveMovements = () => {
  const { currentVillage } = useCurrentVillage();
  const { troopMovements } = useVillageTroopMovements();

  const visibleMovements = useMemo(
    () => troopMovements.slice(0, 6),
    [troopMovements],
  );

  if (troopMovements.length === 0) {
    return null;
  }

  return (
    <aside className="absolute bottom-8 left-4 z-30 hidden w-[min(26rem,calc(100vw-2rem))] rounded-md border border-black/20 bg-white/95 p-3 text-sm shadow-lg lg:block dark:border-white/15 dark:bg-neutral-950/95">
      <div className="mb-2 flex items-center justify-between gap-3">
        <div>
          <h2 className="font-semibold">Active movements</h2>
          <p className="text-xs text-muted-foreground">
            Raids, attacks, returns, and reinforcements currently travelling.
          </p>
        </div>
        <Link
          className="shrink-0 rounded border px-2 py-1 text-xs font-semibold hover:bg-muted"
          to="../village/39?tab=troop-movements"
          relative="path"
        >
          Rally Point
        </Link>
      </div>
      <div className="space-y-1.5">
        {visibleMovements.map((movement) => {
          const isOffensive = offensiveTypes.has(movement.type);
          const direction = getMovementDirection(movement, currentVillage.id);

          return (
            <div
              className="grid grid-cols-[5.5rem_1fr_4.5rem] items-center gap-2 rounded border border-border/80 bg-background/90 px-2 py-1.5"
              key={movement.id}
            >
              <div>
                <div className="font-semibold leading-tight">
                  {movementLabels[movement.type]}
                </div>
                <div className={isOffensive ? 'text-xs text-red-600' : 'text-xs text-muted-foreground'}>
                  {direction}
                </div>
              </div>
              <div className="min-w-0">
                <div className="truncate font-medium">{getMovementTarget(movement)}</div>
                <div className="truncate text-xs text-muted-foreground">
                  From {movement.originatingVillageName} {formatCoords(movement.originatingX, movement.originatingY)}
                </div>
              </div>
              <div className="text-right font-semibold tabular-nums">
                <Countdown endsAt={movement.resolvesAt} />
              </div>
            </div>
          );
        })}
      </div>
      {troopMovements.length > visibleMovements.length && (
        <p className="mt-2 text-xs text-muted-foreground">
          {troopMovements.length - visibleMovements.length} more movement(s) in Rally Point.
        </p>
      )}
    </aside>
  );
};
""")

page_path = 'apps/web/app/(game)/(village-slug)/(map)/page.tsx'
replace_once(
    page_path,
    "import { MapControls } from 'app/(game)/(village-slug)/(map)/components/map-controls';",
    "import { MapActiveMovements } from 'app/(game)/(village-slug)/(map)/components/map-active-movements';\nimport { MapControls } from 'app/(game)/(village-slug)/(map)/components/map-controls';",
)
replace_once(
    page_path,
    "      <MapControls />",
    "      <MapActiveMovements />\n      <MapControls />",
)
PY

# LAN Arcade phase upgrade patch 2026-06-23 usability fixes: actual farm list tabs and scout affordances.
echo "Applying LAN Arcade usability fix patch 2026-06-23..."
python3 <<'PY'
from pathlib import Path

root = Path.cwd()

def replace_once(path, old, new):
    p = root / path
    text = p.read_text()
    if new in text:
        return
    if old not in text:
        raise SystemExit(f'pattern not found in {path}: {old[:160]!r}')
    p.write_text(text.replace(old, new, 1))

# Farm-list mutations need to invalidate both the list and the details query.
hook_path = 'apps/web/app/(game)/(village-slug)/hooks/use-farm-lists.ts'
replace_once(
    hook_path,
    """    onSuccess: async (_data, _vars, _onMutateResult, context) => {
      await invalidateQueries(context, [
        [farmListsCacheKey, currentVillage.id],
      ]);
    },
  });

  const { mutate: removeTileFromFarmList } = useMutation({""",
    """    onSuccess: async (_data, vars, _onMutateResult, context) => {
      await invalidateQueries(context, [
        [farmListsCacheKey],
        [farmListsCacheKey, vars.farmListId],
      ]);
    },
  });

  const { mutate: removeTileFromFarmList } = useMutation({""",
)
replace_once(
    hook_path,
    """    onSuccess: async (_data, _vars, _onMutateResult, context) => {
      await invalidateQueries(context, [
        [farmListsCacheKey, currentVillage.id],
      ]);
    },
  });

  return {""",
    """    onSuccess: async (_data, vars, _onMutateResult, context) => {
      await invalidateQueries(context, [
        [farmListsCacheKey],
        [farmListsCacheKey, vars.farmListId],
      ]);
    },
  });

  return {""",
)

# The shared farm-list page had the right layout but called the mutation with positional args.
shared_farm_path = 'apps/web/app/(game)/(village-slug)/components/rally-point-farm-list.tsx'
replace_once(
    shared_farm_path,
    "onClick={() => removeTileFromFarmList(farmListId, target.tileId)}",
    "onClick={() => removeTileFromFarmList({ farmListId, tileId: target.tileId })}",
)

# The map modal helper was defined but not rendered, and it used the current-village hook incorrectly.
tile_modal_path = 'apps/web/app/(game)/(village-slug)/(map)/components/tile-modal.tsx'
replace_once(
    tile_modal_path,
    "import { useCurrentVillage } from 'app/(game)/(village-slug)/hooks/current-village/use-current-village';",
    """import { useCurrentVillage } from 'app/(game)/(village-slug)/hooks/current-village/use-current-village';
import { useFarmLists } from 'app/(game)/(village-slug)/hooks/use-farm-lists';""",
)
replace_once(
    tile_modal_path,
    """const TileModalFarmListActions = ({ tile }: TileModalProps) => {
  const { farmLists, addTileToFarmList } = useFarmLists();
  const currentVillage = useCurrentVillage();""",
    """const TileModalFarmListActions = ({ tile }: TileModalProps) => {
  const { farmLists, addTileToFarmList } = useFarmLists();
  const { currentVillage } = useCurrentVillage();""",
)
replace_once(
    tile_modal_path,
    "onClick={() => addTileToFarmList(farmList.id, tile.id)}",
    "onClick={() => addTileToFarmList({ farmListId: farmList.id, tileId: tile.id })}",
)
replace_once(
    tile_modal_path,
    """        {!isOwnedByPlayer && (
          <Text variant=\"link\">
            <Link
              to={`${getVillageBasePath(currentVillage.slug)}/village/39?tab=send-troops&rally-point-send-troops-tab=attack-or-raid&x=${tile.coordinates.x}&y=${tile.coordinates.y}`}
            >
              {t('Attack or raid')}
            </Link>
          </Text>
        )}""",
    """        {!isOwnedByPlayer && (
          <>
            <Text variant=\"link\">
              <Link
                to={`${getVillageBasePath(currentVillage.slug)}/village/39?tab=send-troops&rally-point-send-troops-tab=attack-or-raid&x=${tile.coordinates.x}&y=${tile.coordinates.y}`}
              >
                {t('Attack or raid')}
              </Link>
            </Text>
            <TileModalFarmListActions tile={tile} />
          </>
        )}""",
)

# The Rally Point route imports nested components; replace old placeholders with the working LAN components.
(root / 'apps/web/app/(game)/(village-slug)/(village)/(...building-field-id)/components/components/rally-point/rally-point-farm-list.tsx').write_text(r"""import { useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router';
import { FaPen } from 'react-icons/fa6';
import { LuTrash } from 'react-icons/lu';
import { Bookmark } from 'app/(game)/(village-slug)/(village)/(...building-field-id)/components/components/bookmark';
import { CreateFarmListModal } from 'app/(game)/(village-slug)/(village)/(...building-field-id)/components/components/rally-point/components/farm-list/create-farm-list-modal';
import { EditFarmListModal } from 'app/(game)/(village-slug)/(village)/(...building-field-id)/components/components/rally-point/components/farm-list/edit-farm-list-modal';
import {
  Section,
  SectionContent,
} from 'app/(game)/(village-slug)/components/building-layout';
import { farmListsCacheKey } from 'app/(game)/constants/query-keys';
import { useFarmLists } from 'app/(game)/(village-slug)/hooks/use-farm-lists';
import { usePlayerVillageListing } from 'app/(game)/(village-slug)/hooks/use-player-village-listing';
import { Text } from 'app/components/text';
import { Button } from 'app/components/ui/button';
import { useDialog } from 'app/hooks/use-dialog';

const FarmListTargets = ({ farmListId, targetCount }: { farmListId: number; targetCount: number }) => {
  const { getFarmList, removeTileFromFarmList } = useFarmLists();
  const { data: details, isLoading } = useQuery({
    queryKey: [farmListsCacheKey, farmListId],
    queryFn: () => getFarmList(farmListId),
    enabled: targetCount > 0,
  });

  if (targetCount === 0) {
    return (
      <div className="border-t bg-muted/10 p-4 text-center text-sm text-muted-foreground">
        No targets yet. Open another village on the map and click Add to farm list.
      </div>
    );
  }

  if (isLoading || !details) {
    return <div className="border-t p-4 text-sm text-muted-foreground">Loading farm targets...</div>;
  }

  return (
    <div className="divide-y border-t">
      {details.targets.map((target) => {
        const title = target.villageName ?? `Tile (${target.x}|${target.y})`;
        const owner = target.playerName ? ` by ${target.playerName}` : '';
        return (
          <div className="flex flex-wrap items-center justify-between gap-3 p-3" key={target.tileId}>
            <div className="min-w-48">
              <Text className="font-semibold">{title} ({target.x}|{target.y})</Text>
              <Text className="text-sm text-muted-foreground">
                {target.tribe ? `${target.tribe} village${owner}` : `Map target${owner}`}
                {typeof target.population === 'number' && target.population > 0 ? ` - pop ${target.population}` : ''}
              </Text>
            </div>
            <div className="flex items-center gap-2">
              <Button size="sm" variant="outline" asChild>
                <Link to={`?tab=send-troops&rally-point-send-troops-tab=attack-or-raid&x=${target.x}&y=${target.y}`}>Raid</Link>
              </Button>
              <Button
                aria-label={`Remove ${title} from farm list`}
                size="icon"
                variant="ghost"
                onClick={() => removeTileFromFarmList({ farmListId, tileId: target.tileId })}
              >
                <LuTrash className="size-4 text-destructive" />
              </Button>
            </div>
          </div>
        );
      })}
    </div>
  );
};

export const RallyPointFarmList = () => {
  const {
    isOpen: isCreateFarmListModalOpen,
    openModal: openCreateFarmListModalOpen,
    closeModal: closeCreateFarmListModal,
  } = useDialog();
  const {
    isOpen: isEditFarmListModalOpen,
    openModal: openEditFarmListModalOpen,
    closeModal: closeEditFarmListModal,
    modalArgs: editModalArgs,
  } = useDialog<number>();
  const { farmLists, deleteFarmList } = useFarmLists();
  const { playerVillages } = usePlayerVillageListing();

  const farmListsByVillage = useMemo(() => {
    return playerVillages.map((village) => ({
      ...village,
      farmLists: farmLists.filter((farmList) => farmList.villageId === village.id),
    }));
  }, [farmLists, playerVillages]);

  return (
    <Section>
      <SectionContent>
        <Bookmark tab="farm-list" />
        <Text as="h2">Farm List</Text>
        <Text>Save repeat raid targets from the map, then return here to open pre-filled raid orders.</Text>
        <Text className="font-medium">You currently have {farmLists.length} farm {farmLists.length === 1 ? 'list' : 'lists'}.</Text>
      </SectionContent>
      <SectionContent>
        <div className="flex w-full justify-end">
          <Button size="sm" onClick={() => openCreateFarmListModalOpen()}>
            Create new list
          </Button>
        </div>
      </SectionContent>
      {farmListsByVillage.map((village) => (
        <SectionContent key={village.id}>
          <div className="flex w-full flex-col gap-2">
            <Text className="font-semibold">{village.name}</Text>
            {village.farmLists.length === 0 ? (
              <div className="rounded border p-4 text-sm text-muted-foreground">No farm lists for this village yet.</div>
            ) : (
              <div className="flex flex-col gap-4">
                {village.farmLists.map((list) => (
                  <div className="overflow-hidden rounded border" key={list.id}>
                    <div className="flex flex-wrap items-center justify-between gap-3 bg-muted/40 p-3">
                      <div>
                        <Text className="font-medium">{list.name}</Text>
                        <Text className="text-sm text-muted-foreground">{list.targetCount}/100 targets</Text>
                      </div>
                      <div className="flex items-center gap-1">
                        <Button variant="ghost" size="icon" onClick={() => openEditFarmListModalOpen(list.id)}>
                          <FaPen className="size-4" />
                        </Button>
                        <Button variant="ghost" size="icon" onClick={() => deleteFarmList(list.id)}>
                          <LuTrash className="size-4 text-destructive" />
                        </Button>
                      </div>
                    </div>
                    <FarmListTargets farmListId={list.id} targetCount={list.targetCount} />
                  </div>
                ))}
              </div>
            )}
          </div>
        </SectionContent>
      ))}
      <CreateFarmListModal isOpen={isCreateFarmListModalOpen} onClose={closeCreateFarmListModal} />
      <EditFarmListModal isOpen={isEditFarmListModalOpen} id={editModalArgs.current!} onClose={closeEditFarmListModal} />
    </Section>
  );
};
""")
(root / 'apps/web/app/(game)/(village-slug)/(village)/(...building-field-id)/components/components/rally-point/rally-point-simulator.tsx').write_text(r"""import { useMemo, useState } from 'react';
import { Bookmark } from 'app/(game)/(village-slug)/(village)/(...building-field-id)/components/components/bookmark';
import {
  Section,
  SectionContent,
} from 'app/(game)/(village-slug)/components/building-layout';
import { Text } from 'app/components/text';
import { Button } from 'app/components/ui/button';
import { Input } from 'app/components/ui/input';
import { Label } from 'app/components/ui/label';

const numberOrZero = (value: string) => Number.isFinite(Number(value)) ? Math.max(0, Number(value)) : 0;

export const RallyPointSimulator = () => {
  const [attackPower, setAttackPower] = useState('1000');
  const [defencePower, setDefencePower] = useState('700');
  const [attackerCount, setAttackerCount] = useState('100');
  const [defenderCount, setDefenderCount] = useState('60');
  const [mode, setMode] = useState<'raid' | 'attack'>('raid');

  const result = useMemo(() => {
    const attack = numberOrZero(attackPower);
    const defence = numberOrZero(defencePower);
    const attackers = numberOrZero(attackerCount);
    const defenders = numberOrZero(defenderCount);
    const total = Math.max(1, attack + defence);
    const attackerLossRatio = mode === 'raid'
      ? Math.min(1, Math.max(0, defence / total) * 0.65)
      : Math.min(1, Math.max(0, defence / total) * 1.1);
    const defenderLossRatio = mode === 'raid'
      ? Math.min(1, Math.max(0, attack / total) * 0.45)
      : Math.min(1, Math.max(0, attack / total) * 1.15);
    const attackerLosses = Math.min(attackers, Math.ceil(attackers * attackerLossRatio));
    const defenderLosses = Math.min(defenders, Math.ceil(defenders * defenderLossRatio));
    return {
      attackerLosses,
      defenderLosses,
      survivingAttackers: Math.max(0, attackers - attackerLosses),
      survivingDefenders: Math.max(0, defenders - defenderLosses),
    };
  }, [attackPower, defencePower, attackerCount, defenderCount, mode]);

  return (
    <Section>
      <SectionContent>
        <Bookmark tab="simulator" />
        <Text as="h2">Simulator</Text>
        <Text>Estimate LAN Arcade combat before sending a raid or normal attack. Actual results still depend on exact unit stats and surviving carry capacity.</Text>
      </SectionContent>
      <SectionContent>
        <div className="grid w-full gap-4 md:grid-cols-2">
          <Label className="flex flex-col gap-2">Attack power
            <Input inputMode="numeric" value={attackPower} onChange={(event) => setAttackPower(event.target.value)} />
          </Label>
          <Label className="flex flex-col gap-2">Defence power
            <Input inputMode="numeric" value={defencePower} onChange={(event) => setDefencePower(event.target.value)} />
          </Label>
          <Label className="flex flex-col gap-2">Attackers sent
            <Input inputMode="numeric" value={attackerCount} onChange={(event) => setAttackerCount(event.target.value)} />
          </Label>
          <Label className="flex flex-col gap-2">Defenders present
            <Input inputMode="numeric" value={defenderCount} onChange={(event) => setDefenderCount(event.target.value)} />
          </Label>
        </div>
        <div className="flex gap-2">
          <Button size="sm" variant={mode === 'raid' ? 'default' : 'outline'} onClick={() => setMode('raid')}>Raid</Button>
          <Button size="sm" variant={mode === 'attack' ? 'default' : 'outline'} onClick={() => setMode('attack')}>Normal attack</Button>
        </div>
        <Text className="font-medium">Estimated result</Text>
        <div className="grid w-full gap-3 md:grid-cols-4">
          <div className="rounded border p-3"><Text className="text-sm text-muted-foreground">Attacker losses</Text><Text className="font-semibold">{result.attackerLosses}</Text></div>
          <div className="rounded border p-3"><Text className="text-sm text-muted-foreground">Defender losses</Text><Text className="font-semibold">{result.defenderLosses}</Text></div>
          <div className="rounded border p-3"><Text className="text-sm text-muted-foreground">Attackers return</Text><Text className="font-semibold">{result.survivingAttackers}</Text></div>
          <div className="rounded border p-3"><Text className="text-sm text-muted-foreground">Defenders remain</Text><Text className="font-semibold">{result.survivingDefenders}</Text></div>
        </div>
      </SectionContent>
    </Section>
  );
};
""")
(root / 'apps/web/app/(game)/(village-slug)/(village)/(...building-field-id)/components/components/rally-point/rally-point-troop-movements.tsx').write_text("""import { Link } from 'react-router';
import { Bookmark } from 'app/(game)/(village-slug)/(village)/(...building-field-id)/components/components/bookmark';
import { Countdown } from 'app/(game)/(village-slug)/components/countdown';
import {
  Section,
  SectionContent,
} from 'app/(game)/(village-slug)/components/building-layout';
import { useCurrentVillage } from 'app/(game)/(village-slug)/hooks/current-village/use-current-village';
import { useVillageTroopMovements } from 'app/(game)/(village-slug)/hooks/use-village-troop-movements';
import { Text } from 'app/components/text';

const movementLabels = {
  troopMovementAdventure: 'Adventure',
  troopMovementAttack: 'Attack',
  troopMovementFindNewVillage: 'Settlers',
  troopMovementOasisOccupation: 'Oasis',
  troopMovementRaid: 'Raid',
  troopMovementReinforcements: 'Reinforce',
  troopMovementRelocation: 'Relocate',
  troopMovementReturn: 'Return',
} as const;

const formatCoords = (x: number | null | undefined, y: number | null | undefined) => {
  if (typeof x !== 'number' || typeof y !== 'number') return null;
  return `(${x}|${y})`;
};

export const RallyPointTroopMovements = () => {
  const { currentVillage } = useCurrentVillage();
  const { troopMovements } = useVillageTroopMovements();

  return (
    <Section>
      <SectionContent>
        <Bookmark tab="troop-movements" />
        <Text as="h2">Troop movements</Text>
        <Text>Active raids, attacks, reinforcements, settlers, adventures, and returning troops related to this village.</Text>
      </SectionContent>
      <SectionContent>
        {troopMovements.length === 0 ? (
          <div className="rounded border p-4 text-sm text-muted-foreground">
            No active troop movements for this village.
          </div>
        ) : (
          <div className="flex w-full flex-col gap-2">
            {troopMovements.map((movement) => {
              const targetCoords = movement.type === 'troopMovementAdventure'
                ? null
                : formatCoords(movement.targetX, movement.targetY);
              const targetName = movement.type === 'troopMovementAdventure'
                ? 'Adventure site'
                : movement.targetVillageName ?? 'map tile';
              const originCoords = formatCoords(movement.originatingX, movement.originatingY);
              const direction = movement.type === 'troopMovementReturn'
                ? 'Returning'
                : movement.originatingVillageId === currentVillage.id ? 'Outgoing' : 'Incoming';

              return (
                <div className="grid gap-2 rounded border p-3 md:grid-cols-[8rem_1fr_7rem] md:items-center" key={movement.id}>
                  <div>
                    <Text className="font-semibold">{movementLabels[movement.type]}</Text>
                    <Text className="text-sm text-muted-foreground">{direction}</Text>
                  </div>
                  <div className="min-w-0">
                    <Text className="font-medium">{targetName}{targetCoords ? ` ${targetCoords}` : ''}</Text>
                    <Text className="text-sm text-muted-foreground">
                      From {movement.originatingVillageName}{originCoords ? ` ${originCoords}` : ''}
                    </Text>
                  </div>
                  <div className="text-left font-semibold tabular-nums md:text-right">
                    <Countdown endsAt={movement.resolvesAt} />
                  </div>
                </div>
              );
            })}
          </div>
        )}
        <Text className="text-sm text-muted-foreground">
          Want to send another raid? Open a saved target in Farm List or choose a tile on the map.
        </Text>
        <Text variant="link">
          <Link to="../map" relative="path">Back to map</Link>
        </Text>
      </SectionContent>
    </Section>
  );
};
""")

# Make scouting discoverable instead of an invisible rule.
attack_path = 'apps/web/app/(game)/(village-slug)/components/send-troops/attack-raid-form.tsx'
replace_once(
    attack_path,
    "const { control } = useFormContext<AttackRaidFormValues>();",
    "const { control, setValue } = useFormContext<AttackRaidFormValues>();",
)
replace_once(
    attack_path,
    """  const selectedUnits = useMemo(() => (units ?? []).filter((unit) => unit.selected > 0), [units]);
  const isScoutOnlyMission = selectedUnits.length > 0 && selectedUnits.every((unit) => unit.unitId.endsWith('_SCOUT'));""",
    """  const selectedUnits = useMemo(() => (units ?? []).filter((unit) => unit.selected > 0), [units]);
  const scoutUnits = useMemo(() => (units ?? []).filter((unit) => unit.unitId.endsWith('_SCOUT') && unit.available > 0), [units]);
  const isScoutOnlyMission = selectedUnits.length > 0 && selectedUnits.every((unit) => unit.unitId.endsWith('_SCOUT'));
  const isMixedScoutMission = selectedUnits.some((unit) => unit.unitId.endsWith('_SCOUT')) && selectedUnits.some((unit) => !unit.unitId.endsWith('_SCOUT'));
  const selectScoutMission = () => {
    (units ?? []).forEach((unit, index) => {
      setValue(`units.${index}.selected`, unit.unitId.endsWith('_SCOUT') ? unit.available : 0, {
        shouldDirty: true,
        shouldValidate: true,
      });
    });
    setValue('action', 'attack_raid', { shouldDirty: true, shouldValidate: true });
  };""",
)
replace_once(
    attack_path,
    """        {isScoutOnlyMission ? (
          <Text className=\"rounded-md border border-border bg-muted/40 p-2 text-sm text-muted-foreground\">
            {t('Scout-only missions return an intel report and do not loot resources.')}
          </Text>
        ) : null}""",
    """        <div className="rounded-md border border-border bg-muted/40 p-2 text-sm text-muted-foreground">
          <Text className="font-medium">{t('Scouting')}</Text>
          <Text>{t('To scout, send only scout/pathfinder units. Mixed groups become intel missions; raids and attacks use fighting troops.')}</Text>
          {scoutUnits.length > 0 ? (
            <Button className="mt-2" size="sm" type="button" variant="outline" onClick={selectScoutMission}>
              {t('Scout with all scouts')}
            </Button>
          ) : (
            <Text className="mt-2 text-sm text-muted-foreground">{t('No scouts are stationed here. Train scouts or move them into this village before sending an intel mission.')}</Text>
          )}
        </div>
        {isScoutOnlyMission ? (
          <Text className="rounded-md border border-border bg-muted/40 p-2 text-sm text-muted-foreground">
            {t('Scout mission ready: this returns an intel report and does not loot resources.')}
          </Text>
        ) : null}
        {isMixedScoutMission ? (
          <Text className="rounded-md border border-warning/40 bg-warning/10 p-2 text-sm text-warning">
            {t('Scouts mixed with fighting units will travel as part of the raid; select only scouts for an intel mission.')}
          </Text>
        ) : null}""",
)
# Avoid false confidence: tile intel is not a real scout report until scouts are sent.
replace_once(
    tile_modal_path,
    "{t('No defenders detected')}",
    "{t('No current scout intel')}",
)
replace_once(
    attack_path,
    "{t('No defenders detected at this tile.')}",
    "{t('No current scout intel for this tile. Send a scout-only mission for reliable defender numbers.')}",
)

# Player combat/economy statistics tab for LAN Arcade backfilled stats.
(root / 'apps/web/app/(game)/(village-slug)/(statistics)/components/my-statistics.tsx').write_text(r"""import { use, useMemo } from 'react';
import { useSuspenseQueries } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import type { Troop } from '@pillage-first/types/models/troop';
import { Section, SectionContent } from 'app/(game)/(village-slug)/components/building-layout';
import { useEventsHistory } from 'app/(game)/(village-slug)/hooks/use-events-history';
import { usePlayerVillageListing } from 'app/(game)/(village-slug)/hooks/use-player-village-listing';
import { useReports } from 'app/(game)/(village-slug)/hooks/use-reports';
import { villageTroopsCacheKey } from 'app/(game)/constants/query-keys';
import { ApiContext } from 'app/(game)/providers/api-provider';
import { Text } from 'app/components/text';

type CountMap = Record<string, number>;
type ResourceTotals = {
  wood: number;
  clay: number;
  iron: number;
  wheat: number;
  unknown: number;
};

const numberFormatter = new Intl.NumberFormat();
const combatReportTypes = new Set(['attack', 'raid', 'defence', 'scout-attack', 'scout-defence']);

const emptyResources = (): ResourceTotals => ({
  wood: 0,
  clay: 0,
  iron: 0,
  wheat: 0,
  unknown: 0,
});

const addCount = (target: CountMap, unitId: string, amount: number) => {
  if (!Number.isFinite(amount) || amount <= 0) {
    return;
  }

  target[unitId] = (target[unitId] ?? 0) + amount;
};

const totalCount = (values: CountMap) => {
  return Object.values(values).reduce((sum, amount) => sum + amount, 0);
};

const formatNumber = (value: number) => numberFormatter.format(Math.max(0, Math.floor(value)));

const normalizeUnitId = (value: string) => {
  return value
    .trim()
    .replace(/[.:;]+$/g, '')
    .replace(/['?]/g, '')
    .replace(/[^a-zA-Z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .toUpperCase();
};

const titleCaseUnitId = (unitId: string) => {
  return unitId
    .toLowerCase()
    .replaceAll('_', ' ')
    .replace(/\b\w/g, (letter) => letter.toUpperCase());
};

const escapeRegExp = (value: string) => {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
};

const extractReportField = (body: string, label: string) => {
  const match = body.match(new RegExp(`${escapeRegExp(label)}:\\s*([^.]*)`, 'i'));
  return match?.[1]?.trim() ?? '';
};

const parseTroopList = (value: string) => {
  if (!value || /^(none|no defenders detected|no current scout intel)$/i.test(value.trim())) {
    return [] as { unitId: string; amount: number }[];
  }

  return value
    .split(',')
    .map((part) => part.trim())
    .flatMap((part) => {
      const match = part.match(/^([0-9][0-9,]*)\s+(.+)$/);
      if (!match) {
        return [];
      }

      const amount = Number(match[1].replaceAll(',', ''));
      const unitId = normalizeUnitId(match[2]);
      return Number.isFinite(amount) && unitId ? [{ unitId, amount }] : [];
    });
};

const parseResourceBundle = (value: string) => {
  const match = value.match(
    /([0-9][0-9,]*)\s+wood,\s*([0-9][0-9,]*)\s+clay,\s*([0-9][0-9,]*)\s+iron,\s*([0-9][0-9,]*)\s+wheat/i,
  );

  if (!match) {
    return null;
  }

  return {
    wood: Number(match[1].replaceAll(',', '')),
    clay: Number(match[2].replaceAll(',', '')),
    iron: Number(match[3].replaceAll(',', '')),
    wheat: Number(match[4].replaceAll(',', '')),
  };
};

const parseTitleLoot = (title: string) => {
  const match = title.match(/raid gained\s+([0-9][0-9,]*)\s+resources/i);
  return match ? Number(match[1].replaceAll(',', '')) : 0;
};

const usePlayerCurrentTroopTotals = () => {
  const { apiClient } = use(ApiContext);
  const { playerVillages } = usePlayerVillageListing();
  const playerTileIds = useMemo(
    () => new Set(playerVillages.map(({ tileId }) => tileId)),
    [playerVillages],
  );
  const troopQueries = useSuspenseQueries({
    queries: playerVillages.map((village) => ({
      queryKey: [villageTroopsCacheKey, village.id, 'statistics'],
      queryFn: async () => {
        const { data } = await apiClient.get('/tiles/:tileId/stationed-troops', {
          path: { tileId: village.tileId },
        });
        return data as Troop[];
      },
    })),
  });

  return useMemo(() => {
    const totals: CountMap = {};

    for (const { data } of troopQueries) {
      for (const troop of data as Troop[]) {
        if (playerTileIds.has(troop.tileId) && playerTileIds.has(troop.source)) {
          addCount(totals, troop.unitId, troop.amount);
        }
      }
    }

    return totals;
  }, [playerTileIds, troopQueries]);
};

const useMyStatistics = () => {
  const { reports } = useReports();
  const { events } = useEventsHistory('global', ['training']);
  const currentTroops = usePlayerCurrentTroopTotals();

  return useMemo(() => {
    const loot = emptyResources();
    const attackerLosses: CountMap = {};
    const defenderLosses: CountMap = {};
    const defendersFaced: CountMap = {};
    const training: CountMap = {};
    const reportCounts: CountMap = {};
    let reportsBackfilled = 0;
    let bestLootReport = { title: '', total: 0 };

    for (const event of events) {
      if (event.type === 'training') {
        addCount(training, event.data.unit, event.data.amount);
      }
    }

    for (const report of reports) {
      if (!combatReportTypes.has(report.type)) {
        continue;
      }

      reportsBackfilled += 1;
      addCount(reportCounts, report.type, 1);

      const parsedLoot = parseResourceBundle(extractReportField(report.body, 'Loot') || report.body);
      if (parsedLoot) {
        loot.wood += parsedLoot.wood;
        loot.clay += parsedLoot.clay;
        loot.iron += parsedLoot.iron;
        loot.wheat += parsedLoot.wheat;
        const total = parsedLoot.wood + parsedLoot.clay + parsedLoot.iron + parsedLoot.wheat;
        if (total > bestLootReport.total) {
          bestLootReport = { title: report.title, total };
        }
      } else {
        const titleLoot = parseTitleLoot(report.title);
        loot.unknown += titleLoot;
        if (titleLoot > bestLootReport.total) {
          bestLootReport = { title: report.title, total: titleLoot };
        }
      }

      for (const troop of parseTroopList(extractReportField(report.body, 'Attacker losses'))) {
        addCount(attackerLosses, troop.unitId, troop.amount);
      }
      for (const troop of parseTroopList(extractReportField(report.body, 'Defender losses'))) {
        addCount(defenderLosses, troop.unitId, troop.amount);
      }
      for (const troop of parseTroopList(extractReportField(report.body, 'Defenders present'))) {
        addCount(defendersFaced, troop.unitId, troop.amount);
      }
    }

    const minimumAccountedTroops: CountMap = {};
    const allUnitIds = new Set([
      ...Object.keys(training),
      ...Object.keys(currentTroops),
      ...Object.keys(attackerLosses),
    ]);

    for (const unitId of allUnitIds) {
      minimumAccountedTroops[unitId] = Math.max(
        training[unitId] ?? 0,
        (currentTroops[unitId] ?? 0) + (attackerLosses[unitId] ?? 0),
      );
    }

    return {
      loot,
      attackerLosses,
      defenderLosses,
      defendersFaced,
      training,
      currentTroops,
      minimumAccountedTroops,
      reportCounts,
      reportsBackfilled,
      bestLootReport,
    };
  }, [currentTroops, events, reports]);
};

type StatCardProps = {
  label: string;
  value: string;
  caption?: string;
};

const StatCard = ({ label, value, caption }: StatCardProps) => (
  <div className="rounded-md border border-border bg-card/70 p-3">
    <Text className="text-sm text-muted-foreground">{label}</Text>
    <Text className="text-2xl font-semibold tabular-nums">{value}</Text>
    {caption ? <Text className="text-xs text-muted-foreground">{caption}</Text> : null}
  </div>
);

type BreakdownListProps = {
  title: string;
  values: CountMap;
  emptyText: string;
  unitLabel: (unitId: string, count: number) => string;
};

const sortedEntries = (values: CountMap) => {
  return Object.entries(values).sort(([, a], [, b]) => b - a);
};

const BreakdownList = ({ title, values, emptyText, unitLabel }: BreakdownListProps) => {
  const entries = sortedEntries(values);

  return (
    <div className="rounded-md border border-border bg-background/60 p-3">
      <Text as="h3" className="font-semibold">{title}</Text>
      {entries.length === 0 ? (
        <Text className="text-sm text-muted-foreground">{emptyText}</Text>
      ) : (
        <div className="mt-2 flex flex-col gap-1">
          {entries.map(([unitId, count]) => (
            <div className="flex items-center justify-between gap-3 text-sm" key={unitId}>
              <span className="min-w-0 break-words">{unitLabel(unitId, count)}</span>
              <span className="font-semibold tabular-nums">{formatNumber(count)}</span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export const MyStatistics = () => {
  const { t } = useTranslation();
  const stats = useMyStatistics();
  const knownLootTotal = stats.loot.wood + stats.loot.clay + stats.loot.iron + stats.loot.wheat;
  const totalLoot = knownLootTotal + stats.loot.unknown;
  const trainingTotal = totalCount(stats.training);
  const minimumAccountedTotal = totalCount(stats.minimumAccountedTroops);
  const lossesTotal = totalCount(stats.attackerLosses);
  const killsTotal = totalCount(stats.defenderLosses);

  const unitLabel = (unitId: string, count: number) => {
    const translationKey = `UNITS.${unitId}.NAME`;
    const translated = t(translationKey, { count });
    return translated === translationKey ? titleCaseUnitId(unitId) : translated;
  };

  const unitRows = Array.from(
    new Set([
      ...Object.keys(stats.minimumAccountedTroops),
      ...Object.keys(stats.training),
      ...Object.keys(stats.currentTroops),
      ...Object.keys(stats.attackerLosses),
    ]),
  ).sort((a, b) => (stats.minimumAccountedTroops[b] ?? 0) - (stats.minimumAccountedTroops[a] ?? 0));

  return (
    <Section>
      <SectionContent>
        <Text as="h2">{t('My stats')}</Text>
        <Text className="text-sm text-muted-foreground">
          {t('Backfilled from attack, raid, scout, and defence reports plus training history. Older saves may have partial history, so minimum accounted troops uses current troops plus report losses when that is higher than recorded training.')}
        </Text>
      </SectionContent>

      <SectionContent>
        <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-4">
          <StatCard label={t('Total loot')} value={formatNumber(totalLoot)} caption={`${formatNumber(stats.loot.wood)} wood, ${formatNumber(stats.loot.clay)} clay, ${formatNumber(stats.loot.iron)} iron, ${formatNumber(stats.loot.wheat)} wheat${stats.loot.unknown > 0 ? `, ${formatNumber(stats.loot.unknown)} legacy total` : ''}`} />
          <StatCard label={t('Enemies killed')} value={formatNumber(killsTotal)} caption={t('From defender losses in reports')} />
          <StatCard label={t('Troops lost')} value={formatNumber(lossesTotal)} caption={t('From attacker losses in reports')} />
          <StatCard label={t('Troops trained')} value={formatNumber(trainingTotal)} caption={t('Recorded training history')} />
        </div>
        <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-4">
          <StatCard label={t('Minimum accounted troops')} value={formatNumber(minimumAccountedTotal)} caption={t('Training history or current troops plus losses')} />
          <StatCard label={t('Combat reports parsed')} value={formatNumber(stats.reportsBackfilled)} caption={sortedEntries(stats.reportCounts).map(([type, count]) => `${type}: ${formatNumber(count)}`).join(', ') || t('No reports yet')} />
          <StatCard label={t('Best loot run')} value={formatNumber(stats.bestLootReport.total)} caption={stats.bestLootReport.title || t('No loot reports yet')} />
          <StatCard label={t('Current troops')} value={formatNumber(totalCount(stats.currentTroops))} caption={t('Player-owned troops stationed in your villages')} />
        </div>
      </SectionContent>

      <SectionContent>
        <div className="grid gap-3 lg:grid-cols-3">
          <BreakdownList title={t('Kills by enemy type')} values={stats.defenderLosses} emptyText={t('No defender losses found in reports yet.')} unitLabel={unitLabel} />
          <BreakdownList title={t('Losses by unit type')} values={stats.attackerLosses} emptyText={t('No attacker losses found in reports yet.')} unitLabel={unitLabel} />
          <BreakdownList title={t('Defenders faced')} values={stats.defendersFaced} emptyText={t('No defender detail found in reports yet.')} unitLabel={unitLabel} />
        </div>
      </SectionContent>

      <SectionContent>
        <Text as="h3">{t('Troop accounting')}</Text>
        <div className="grid gap-2">
          {unitRows.length === 0 ? (
            <div className="rounded-md border border-border bg-background/60 p-3 text-sm text-muted-foreground">
              {t('No troop history found yet.')}
            </div>
          ) : (
            unitRows.map((unitId) => (
              <div className="grid gap-2 rounded-md border border-border bg-background/60 p-3 text-sm md:grid-cols-[1.3fr_repeat(4,minmax(0,1fr))] md:items-center" key={unitId}>
                <Text className="font-semibold">{unitLabel(unitId, stats.minimumAccountedTroops[unitId] ?? 0)}</Text>
                <div><span className="text-muted-foreground">{t('trained')}</span> <span className="font-semibold tabular-nums">{formatNumber(stats.training[unitId] ?? 0)}</span></div>
                <div><span className="text-muted-foreground">{t('current')}</span> <span className="font-semibold tabular-nums">{formatNumber(stats.currentTroops[unitId] ?? 0)}</span></div>
                <div><span className="text-muted-foreground">{t('lost')}</span> <span className="font-semibold tabular-nums">{formatNumber(stats.attackerLosses[unitId] ?? 0)}</span></div>
                <div><span className="text-muted-foreground">{t('minimum')}</span> <span className="font-semibold tabular-nums">{formatNumber(stats.minimumAccountedTroops[unitId] ?? 0)}</span></div>
              </div>
            ))
          )}
        </div>
      </SectionContent>
    </Section>
  );
};
""")

statistics_page = 'apps/web/app/(game)/(village-slug)/(statistics)/page.tsx'
replace_once(
    statistics_page,
    "import { VillageRankings } from 'app/(game)/(village-slug)/(statistics)/components/village-rankings';",
    "import { MyStatistics } from 'app/(game)/(village-slug)/(statistics)/components/my-statistics';\nimport { VillageRankings } from 'app/(game)/(village-slug)/(statistics)/components/village-rankings';",
)
replace_once(
    statistics_page,
    "const tabs = ['population', 'villages', 'overview'];",
    "const tabs = ['my-stats', 'population', 'villages', 'overview'];",
)
replace_once(
    statistics_page,
    "value={tabs[tabIndex] ?? 'population'}",
    "value={tabs[tabIndex] ?? 'my-stats'}",
)
replace_once(
    statistics_page,
    "          <Tab value=\"population\">{t('Population')}</Tab>",
    "          <Tab value=\"my-stats\">{t('My stats')}</Tab>\n          <Tab value=\"population\">{t('Population')}</Tab>",
)
replace_once(
    statistics_page,
    "        <TabPanel value=\"population\">\n          <PopulationRankings />\n        </TabPanel>",
    "        <TabPanel value=\"my-stats\">\n          <MyStatistics />\n        </TabPanel>\n        <TabPanel value=\"population\">\n          <PopulationRankings />\n        </TabPanel>",
)

PY


# LAN Arcade usability fix patch 2026-06-24: troop movement manifests and send guards.
echo "Applying LAN Arcade usability fix patch 2026-06-24 troop movement manifests..."
python3 - <<'PY'
from pathlib import Path

root = Path('.')

def replace_once(path, old, new):
    p = root / path
    text = p.read_text()
    if new in text:
        return
    if old not in text:
        raise SystemExit(f'marker not found in {path}: {old[:120]}')
    p.write_text(text.replace(old, new, 1))

# Expose troop manifests in the movement DTO.
dto_path = root / 'packages/types/src/dtos/troop-movement.ts'
dto = dto_path.read_text()
if "../models/unit" not in dto:
    dto = dto.replace(
        "import { tribeSchema } from '../models/tribe';",
        "import { tribeSchema } from '../models/tribe';\nimport { unitIdSchema } from '../models/unit';",
        1,
    )
if 'troopMovementTroopDtoSchema' not in dto:
    dto = dto.replace(
        "const villageTargetTroopMovementTypeSchema = gameEventTypeSchema.extract([",
        "const troopMovementTroopDtoSchema = z.strictObject({\n  unitId: unitIdSchema,\n  amount: z.number(),\n});\n\nconst villageTargetTroopMovementTypeSchema = gameEventTypeSchema.extract([",
        1,
    )
if "      troops: z.array(troopMovementTroopDtoSchema)," not in dto:
    dto = dto.replace(
        "      resolvesAt: z.number(),\n    }),",
        "      resolvesAt: z.number(),\n      troops: z.array(troopMovementTroopDtoSchema),\n      totalTroops: z.number(),\n    }),",
        1,
    )
    dto = dto.replace(
        "      resolvesAt: z.number(),\n      targetVillageId: z.number().nullable(),",
        "      resolvesAt: z.number(),\n      troops: z.array(troopMovementTroopDtoSchema),\n      totalTroops: z.number(),\n      targetVillageId: z.number().nullable(),",
        1,
    )
dto_path.write_text(dto)

# Parse movement metadata troops into the DTO.
mapper_path = root / 'packages/api/src/http/controllers/mappers/troop-movement-mapper.ts'
mapper = mapper_path.read_text()
if "import type { z } from 'zod';" in mapper:
    mapper = mapper.replace("import type { z } from 'zod';", "import { z } from 'zod';", 1)
if "@pillage-first/types/models/unit" not in mapper:
    mapper = mapper.replace(
        "} from '@pillage-first/types/dtos/troop-movement';",
        "} from '@pillage-first/types/dtos/troop-movement';\nimport { unitIdSchema } from '@pillage-first/types/models/unit';",
        1,
    )
if 'troopMovementMetaSchema' not in mapper:
    mapper = mapper.replace(
        "import type {\n  getVillageTroopMovementStatsRowSchema,\n  getVillageTroopMovementsRowSchema,\n} from '../schemas/troop-movement-schemas';\n",
        "import type {\n  getVillageTroopMovementStatsRowSchema,\n  getVillageTroopMovementsRowSchema,\n} from '../schemas/troop-movement-schemas';\n\nconst troopMovementMetaSchema = z.looseObject({\n  troops: z.array(z.looseObject({\n    unitId: unitIdSchema,\n    amount: z.number(),\n  })).catch([]),\n});\n\nconst parseMovementTroops = (meta: string) => {\n  try {\n    const parsed = troopMovementMetaSchema.parse(JSON.parse(meta || '{}'));\n    return parsed.troops\n      .filter(({ amount }) => Number.isFinite(amount) && amount > 0)\n      .map(({ unitId, amount }) => ({ unitId, amount }));\n  } catch {\n    return [];\n  }\n};\n",
        1,
    )
if 'const troops = parseMovementTroops(row.meta);' not in mapper:
    mapper = mapper.replace(
        "  const isAdventure = row.type === 'troopMovementAdventure';\n  return troopMovementItemDtoSchema.parse({",
        "  const isAdventure = row.type === 'troopMovementAdventure';\n  const troops = parseMovementTroops(row.meta);\n  const totalTroops = troops.reduce((total, troop) => total + troop.amount, 0);\n  return troopMovementItemDtoSchema.parse({",
        1,
    )
    mapper = mapper.replace(
        "    resolvesAt: row.resolves_at,",
        "    resolvesAt: row.resolves_at,\n    troops,\n    totalTroops,",
        1,
    )
mapper_path.write_text(mapper)

# Validate empty, invalid, and unavailable troop movements server-side.
troops_path = root / 'packages/api/src/utils/troops.ts'
troops = troops_path.read_text()
validation_block = r'''  const movementTroops = troopMovementEvent.troops;
  const fallbackOriginTileId = troopMovementEvent.originTileId ?? database.selectValue({
    sql: 'SELECT tile_id FROM villages WHERE id = $village_id;',
    bind: { $village_id: troopMovementEvent.villageId },
    schema: z.number().nullable(),
  });

  if (!Array.isArray(movementTroops) || movementTroops.length === 0) {
    errors.push('At least one troop must be selected');
  } else {
    const requestedTroops = new Map<string, { unitId: string; amount: number; tileId: number; source: number }>();

    for (const rawTroop of movementTroops) {
      const troop = rawTroop as Partial<Troop>;
      const tileId = troop.tileId ?? fallbackOriginTileId;
      const source = troop.source ?? fallbackOriginTileId;

      if (!Number.isInteger(troop.amount) || (troop.amount ?? 0) <= 0) {
        errors.push('Troop amount must be positive');
        continue;
      }
      if (!troop.unitId || !Number.isInteger(tileId) || !Number.isInteger(source)) {
        errors.push('Troop source tile is invalid');
        continue;
      }

      const key = `${troop.unitId}:${tileId}:${source}`;
      const existing = requestedTroops.get(key);
      requestedTroops.set(key, {
        unitId: troop.unitId,
        amount: (existing?.amount ?? 0) + troop.amount,
        tileId: tileId as number,
        source: source as number,
      });
    }

    for (const troop of requestedTroops.values()) {
      const available = database.selectValue({
        sql: `
          SELECT CAST(COALESCE(SUM(t.amount), 0) AS INTEGER)
          FROM troops t
            JOIN unit_ids ui ON ui.id = t.unit_id
          WHERE ui.unit = $unit_id
            AND t.tile_id = $tile_id
            AND t.source_tile_id = $source_tile_id;
        `,
        bind: {
          $unit_id: troop.unitId,
          $tile_id: troop.tileId,
          $source_tile_id: troop.source,
        },
        schema: z.number(),
      }) ?? 0;

      if (troop.amount > available) {
        errors.push(`Not enough ${troop.unitId} available`);
      }
    }
  }

'''
if 'const movementTroops = troopMovementEvent.troops;' not in troops:
    troops = troops.replace(
        "  if (isAdventureTroopMovementEvent(troopMovementEvent)) {",
        validation_block + "  if (isAdventureTroopMovementEvent(troopMovementEvent)) {",
        1,
    )
troops_path.write_text(troops)

# Render troop manifests on the Rally Point movement list.
movement_path = next(root.glob('apps/web/app/**/rally-point-troop-movements.tsx'))
movement = movement_path.read_text()
if "app/components/icon" not in movement:
    movement = movement.replace(
        "import { useVillageTroopMovements } from 'app/(game)/(village-slug)/hooks/use-village-troop-movements';",
        "import { useVillageTroopMovements } from 'app/(game)/(village-slug)/hooks/use-village-troop-movements';\nimport { Icon } from 'app/components/icon';\nimport { unitIdToUnitIconMapper } from 'app/components/icons/icons';",
        1,
    )
if 'const formatUnitLabel' not in movement:
    movement = movement.replace(
        "const formatCoords = (x: number | null | undefined, y: number | null | undefined) => {\n  if (typeof x !== 'number' || typeof y !== 'number') return null;\n  return `(${x}|${y})`;\n};",
        "const formatCoords = (x: number | null | undefined, y: number | null | undefined) => {\n  if (typeof x !== 'number' || typeof y !== 'number') return null;\n  return `(${x}|${y})`;\n};\n\nconst formatUnitLabel = (unitId: string) =>\n  unitId\n    .toLowerCase()\n    .replaceAll('_', ' ')\n    .replace(/\\b\\w/g, (letter) => letter.toUpperCase());",
        1,
    )
old_card = '''              return (
                <div className="grid gap-2 rounded border p-3 md:grid-cols-[8rem_1fr_7rem] md:items-center" key={movement.id}>
                  <div>
                    <Text className="font-semibold">{movementLabels[movement.type]}</Text>
                    <Text className="text-sm text-muted-foreground">{direction}</Text>
                  </div>
                  <div className="min-w-0">
                    <Text className="font-medium">{targetName}{targetCoords ? ` ${targetCoords}` : ''}</Text>
                    <Text className="text-sm text-muted-foreground">
                      From {movement.originatingVillageName}{originCoords ? ` ${originCoords}` : ''}
                    </Text>
                  </div>
                  <div className="text-left font-semibold tabular-nums md:text-right">
                    <Countdown endsAt={movement.resolvesAt} />
                  </div>
                </div>
              );'''
new_card = '''              const troops = movement.troops.filter(({ amount }) => amount > 0);
              const totalTroops = movement.totalTroops ?? troops.reduce((total, troop) => total + troop.amount, 0);

              return (
                <div className="grid gap-3 rounded border p-3 md:grid-cols-[8rem_1fr_7rem] md:items-start" key={movement.id}>
                  <div>
                    <Text className="font-semibold">{movementLabels[movement.type]}</Text>
                    <Text className="text-sm text-muted-foreground">{direction}</Text>
                  </div>
                  <div className="min-w-0 space-y-2">
                    <div>
                      <Text className="font-medium">{targetName}{targetCoords ? ` ${targetCoords}` : ''}</Text>
                      <Text className="text-sm text-muted-foreground">
                        From {movement.originatingVillageName}{originCoords ? ` ${originCoords}` : ''}
                      </Text>
                    </div>
                    {totalTroops > 0 ? (
                      <div className="flex flex-wrap items-center gap-2 text-sm">
                        <span className="font-semibold tabular-nums">{totalTroops} troops</span>
                        {troops.map(({ unitId, amount }) => (
                          <span
                            key={unitId}
                            className="inline-flex items-center gap-1 rounded-xs border border-border bg-background/70 px-2 py-1 tabular-nums"
                            title={formatUnitLabel(unitId)}
                          >
                            <Icon className="size-4" type={unitIdToUnitIconMapper(unitId)} />
                            {amount}
                          </span>
                        ))}
                      </div>
                    ) : (
                      <Text className="text-sm text-warning">
                        No troops recorded for this movement.
                      </Text>
                    )}
                  </div>
                  <div className="text-left font-semibold tabular-nums md:text-right">
                    <Countdown endsAt={movement.resolvesAt} />
                  </div>
                </div>
              );'''
if old_card in movement:
    movement = movement.replace(old_card, new_card, 1)
elif 'No troops recorded for this movement.' not in movement:
    raise SystemExit('movement card marker not found')
movement_path.write_text(movement)
PY


# LAN Arcade hospital wounded troops patch 2026-06-24
printf 'Applying LAN Arcade hospital wounded troops patch 2026-06-24...\n'
python3 - <<'PY'
from pathlib import Path

root = Path.cwd()

hospital_controller = r'''import { z } from 'zod';
import { PLAYER_ID } from '@pillage-first/game-assets/player';
import { getUnitDefinition } from '@pillage-first/game-assets/utils/units';
import { unitIdSchema } from '@pillage-first/types/models/unit';
import type { Unit } from '@pillage-first/types/models/unit';
import type { DbFacade } from '@pillage-first/utils/facades/database';
import { updateVillageWheatProductionByTroopsAndVillageIdEffectQuery } from '../../queries/effect-queries';
import { addTroops } from '../../utils/troops';
import {
  calculateVillageResourcesAt,
  subtractVillageResourcesAt,
  updateVillageResourcesAt,
} from '../../utils/village';
import { createController } from '../controller';

const resourceBundleSchema = z.tuple([
  z.number(),
  z.number(),
  z.number(),
  z.number(),
]);

const hospitalWoundedTroopDtoSchema = z.strictObject({
  unitId: unitIdSchema,
  amount: z.number(),
  healCost: resourceBundleSchema,
  unitWheatConsumption: z.number(),
});

const woundedTroopRowSchema = z.strictObject({
  unitId: unitIdSchema,
  amount: z.number(),
});

const villageTileRowSchema = z.strictObject({
  tileId: z.number(),
});

const ensureLanArcadeWoundedTroopsTable = (database: DbFacade) => {
  database.exec({
    sql: `
      CREATE TABLE IF NOT EXISTS lan_arcade_wounded_troops
      (
        village_id INTEGER NOT NULL,
        unit_id INTEGER NOT NULL,
        amount INTEGER NOT NULL CHECK (amount > 0),
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (village_id, unit_id)
      ) STRICT;
    `,
  });
};

const assertPlayerVillage = (database: DbFacade, villageId: number) => {
  const row = database.selectObject({
    sql: `
      SELECT tile_id AS tileId
      FROM villages
      WHERE id = $village_id
        AND player_id = $player_id;
    `,
    bind: { $village_id: villageId, $player_id: PLAYER_ID },
    schema: villageTileRowSchema,
  });

  if (!row) {
    throw new Error('Village not found');
  }

  return row;
};

const getHospitalLevel = (database: DbFacade, villageId: number) =>
  database.selectValue({
    sql: `
      SELECT COALESCE(MAX(bf.level), 0)
      FROM building_fields bf
        JOIN building_ids bi ON bi.id = bf.building_id
      WHERE bf.village_id = $village_id
        AND bi.building = 'HOSPITAL';
    `,
    bind: { $village_id: villageId },
    schema: z.number(),
  }) ?? 0;

const assertHospitalExists = (database: DbFacade, villageId: number) => {
  if (getHospitalLevel(database, villageId) <= 0) {
    throw new Error('Hospital does not exist');
  }
};

const getHealCost = (unitId: Unit['id'], amount: number) => {
  const { baseRecruitmentCost } = getUnitDefinition(unitId);
  return baseRecruitmentCost.map((cost) => cost * amount) as [number, number, number, number];
};

const mapWoundedTroopRow = (row: z.infer<typeof woundedTroopRowSchema>) => {
  const unit = getUnitDefinition(row.unitId);
  return {
    unitId: row.unitId,
    amount: row.amount,
    healCost: getHealCost(row.unitId, row.amount),
    unitWheatConsumption: unit.unitWheatConsumption,
  };
};

const selectHospitalWoundedTroops = (database: DbFacade, villageId: number) => {
  ensureLanArcadeWoundedTroopsTable(database);

  const rows = database.selectObjects({
    sql: `
      SELECT ui.unit AS unitId, wt.amount
      FROM lan_arcade_wounded_troops wt
        JOIN unit_ids ui ON ui.id = wt.unit_id
      WHERE wt.village_id = $village_id
      ORDER BY ui.unit;
    `,
    bind: { $village_id: villageId },
    schema: woundedTroopRowSchema,
  });

  return rows.map(mapWoundedTroopRow);
};

export const getHospitalWoundedTroops = createController(
  '/villages/:villageId/hospital/wounded-troops',
  {
    summary: 'Get wounded troops available in the hospital',
    requestParams: {
      path: z.strictObject({
        villageId: z.coerce.number(),
      }),
    },
    response: z.array(hospitalWoundedTroopDtoSchema),
  },
)(({ database, path: { villageId } }) => {
  assertPlayerVillage(database, villageId);
  ensureLanArcadeWoundedTroopsTable(database);
  return selectHospitalWoundedTroops(database, villageId);
});

export const healHospitalWoundedTroops = createController(
  '/villages/:villageId/hospital/heal',
  'post',
  {
    summary: 'Heal wounded troops back into the village army',
    requestParams: {
      path: z.strictObject({
        villageId: z.coerce.number(),
      }),
    },
    requestBody: z.strictObject({
      unitId: unitIdSchema,
      amount: z.number().int().positive(),
    }),
    response: z.array(hospitalWoundedTroopDtoSchema),
  },
)(({ database, path: { villageId }, body: { unitId, amount } }) => {
  database.transaction((db) => {
    const { tileId } = assertPlayerVillage(db, villageId);
    assertHospitalExists(db, villageId);
    ensureLanArcadeWoundedTroopsTable(db);

    const available = db.selectValue({
      sql: `
        SELECT amount
        FROM lan_arcade_wounded_troops
        WHERE village_id = $village_id
          AND unit_id = (SELECT id FROM unit_ids WHERE unit = $unit_id);
      `,
      bind: { $village_id: villageId, $unit_id: unitId },
      schema: z.number(),
    }) ?? 0;

    if (amount > available) {
      throw new Error('Not enough wounded troops available');
    }

    const unit = getUnitDefinition(unitId);
    if (unit.id === 'HERO' || !['infantry', 'cavalry'].includes(unit.category)) {
      throw new Error('This unit cannot be healed in the Hospital');
    }

    const now = Date.now();
    const cost = getHealCost(unitId, amount);
    updateVillageResourcesAt(db, villageId, now);
    const resources = calculateVillageResourcesAt(db, villageId, now);

    if (
      resources.currentWood < cost[0]
      || resources.currentClay < cost[1]
      || resources.currentIron < cost[2]
      || resources.currentWheat < cost[3]
    ) {
      throw new Error('Not enough resources to heal wounded troops');
    }

    subtractVillageResourcesAt(db, villageId, now, cost);

    db.exec({
      sql: `
        DELETE FROM lan_arcade_wounded_troops
        WHERE village_id = $village_id
          AND unit_id = (SELECT id FROM unit_ids WHERE unit = $unit_id)
          AND amount <= $amount;
      `,
      bind: { $village_id: villageId, $unit_id: unitId, $amount: amount },
    });

    db.exec({
      sql: `
        UPDATE lan_arcade_wounded_troops
        SET amount = amount - $amount,
            updated_at = $now
        WHERE village_id = $village_id
          AND unit_id = (SELECT id FROM unit_ids WHERE unit = $unit_id)
          AND amount > $amount;
      `,
      bind: {
        $village_id: villageId,
        $unit_id: unitId,
        $amount: amount,
        $now: now,
      },
    });

    addTroops(db, [{ unitId, amount, tileId, source: tileId }]);

    db.exec({
      sql: updateVillageWheatProductionByTroopsAndVillageIdEffectQuery,
      bind: {
        $increase_amount: unit.unitWheatConsumption * amount,
        $village_id: villageId,
      },
    });
  });

  return selectHospitalWoundedTroops(database, villageId);
});
'''
(root / 'packages/api/src/http/controllers/hospital-controllers.ts').write_text(hospital_controller)

api_routes_path = root / 'packages/api/src/http/api-routes.ts'
api_routes = api_routes_path.read_text()
if "hospital-controllers" not in api_routes:
    api_routes = api_routes.replace(
        "} from './controllers/hero-controllers';",
        "} from './controllers/hero-controllers';\nimport {\n  getHospitalWoundedTroops,\n  healHospitalWoundedTroops,\n} from './controllers/hospital-controllers';",
        1,
    )
    api_routes = api_routes.replace(
        "  // Unit Improvements\n  createRoute(getUnitImprovements),",
        "  // Unit Improvements\n  createRoute(getUnitImprovements),\n\n  // Hospital\n  createRoute(getHospitalWoundedTroops),\n  createRoute(healHospitalWoundedTroops),",
        1,
    )
api_routes_path.write_text(api_routes)

resolver_path = root / 'packages/api/src/http/events/resolvers/troop-movement-resolver.ts'
resolver = resolver_path.read_text()
if 'ensureLanArcadeWoundedTroopsTable' not in resolver:
    wound_helpers = r'''
const ensureLanArcadeWoundedTroopsTable = (
  database: Parameters<Resolver<GameEvent<'troopMovementRaid'>>>[0],
) => {
  database.exec({
    sql: `
      CREATE TABLE IF NOT EXISTS lan_arcade_wounded_troops
      (
        village_id INTEGER NOT NULL,
        unit_id INTEGER NOT NULL,
        amount INTEGER NOT NULL CHECK (amount > 0),
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (village_id, unit_id)
      ) STRICT;
    `,
  });
};

const isLanArcadeHospitalWoundEligibleUnit = (unitId: CombatTroop['unitId']) => {
  if (unitId === 'HERO') {
    return false;
  }
  const { category } = getUnitDefinition(unitId);
  return category === 'infantry' || category === 'cavalry';
};

const hospitalVillageRowSchema = z.strictObject({
  villageId: z.number(),
  tileId: z.number(),
});

const recordLanArcadeHospitalWounded = (
  database: Parameters<Resolver<GameEvent<'troopMovementRaid'>>>[0],
  losses: CombatTroop[],
  timestamp: number,
): CombatTroop[] => {
  if (losses.length === 0) {
    return [];
  }

  ensureLanArcadeWoundedTroopsTable(database);
  const wounded: CombatTroop[] = [];
  const stmt = database.prepare({
    sql: `
      INSERT INTO lan_arcade_wounded_troops (village_id, unit_id, amount, created_at, updated_at)
      VALUES (
        $village_id,
        (SELECT id FROM unit_ids WHERE unit = $unit_id),
        $amount,
        $timestamp,
        $timestamp
      )
      ON CONFLICT(village_id, unit_id) DO UPDATE SET
        amount = amount + excluded.amount,
        updated_at = excluded.updated_at;
    `,
  });

  for (const loss of losses) {
    if (loss.amount <= 0 || !isLanArcadeHospitalWoundEligibleUnit(loss.unitId)) {
      continue;
    }

    const hospitalVillage = database.selectObject({
      sql: `
        SELECT v.id AS villageId, v.tile_id AS tileId
        FROM villages v
          JOIN building_fields bf ON bf.village_id = v.id
          JOIN building_ids bi ON bi.id = bf.building_id
        WHERE v.tile_id = $source_tile_id
          AND v.player_id = $player_id
          AND bi.building = 'HOSPITAL'
          AND bf.level > 0
        LIMIT 1;
      `,
      bind: {
        $source_tile_id: loss.source,
        $player_id: PLAYER_ID,
      },
      schema: hospitalVillageRowSchema,
    });

    if (!hospitalVillage) {
      continue;
    }

    const woundedAmount = Math.min(loss.amount, Math.max(1, Math.round(loss.amount * 0.4)));
    stmt.bind({
      $village_id: hospitalVillage.villageId,
      $unit_id: loss.unitId,
      $amount: woundedAmount,
      $timestamp: timestamp,
    }).stepReset();

    wounded.push({
      ...loss,
      amount: woundedAmount,
      tileId: hospitalVillage.tileId,
      source: hospitalVillage.tileId,
    });
  }

  return wounded;
};

'''
    resolver = resolver.replace(
        "const describeCombatReport = (args: {",
        wound_helpers + "const describeCombatReport = (args: {",
        1,
    )
    resolver = resolver.replace(
        "  combat: CombatResult;\n  loot?: RaidResourceBundle;",
        "  combat: CombatResult;\n  attackerWounded?: CombatTroop[];\n  defenderWounded?: CombatTroop[];\n  loot?: RaidResourceBundle;",
        1,
    )
    resolver = resolver.replace(
        "    `Defenders remaining: ${summarizeTroops(args.combat.defenderSurvivors)}.`,\n  ];",
        "    `Defenders remaining: ${summarizeTroops(args.combat.defenderSurvivors)}.`,\n  ];\n\n  if (args.attackerWounded && args.attackerWounded.length > 0) {\n    parts.push(`Attackers wounded in hospital: ${summarizeTroops(args.attackerWounded)}.`);\n  }\n  if (args.defenderWounded && args.defenderWounded.length > 0) {\n    parts.push(`Defenders wounded in hospital: ${summarizeTroops(args.defenderWounded)}.`);\n  }",
        1,
    )
    resolver = resolver.replace(
        "    combat: CombatResult;\n    carriedResources: RaidResourceBundle;",
        "    combat: CombatResult;\n    attackerWounded?: CombatTroop[];\n    defenderWounded?: CombatTroop[];\n    carriedResources: RaidResourceBundle;",
        1,
    )
    resolver = resolver.replace(
        "      combat: args.combat,\n      loot: args.carriedResources,",
        "      combat: args.combat,\n      attackerWounded: args.attackerWounded,\n      defenderWounded: args.defenderWounded,\n      loot: args.carriedResources,",
        1,
    )
    resolver = resolver.replace(
        "    combat: CombatResult;\n  },\n) => {",
        "    combat: CombatResult;\n    attackerWounded?: CombatTroop[];\n    defenderWounded?: CombatTroop[];\n  },\n) => {",
        1,
    )
    resolver = resolver.replace(
        "      combat: args.combat,\n    }),",
        "      combat: args.combat,\n      attackerWounded: args.attackerWounded,\n      defenderWounded: args.defenderWounded,\n    }),",
        1,
    )
    resolver = resolver.replace(
        "  const combat = resolveLanArcadeCombat('attack', troops, defenders);\n\n  removeCombatLosses(database, combat.defenderLosses);",
        "  const combat = resolveLanArcadeCombat('attack', troops, defenders);\n  const attackerWounded = recordLanArcadeHospitalWounded(database, combat.attackerLosses, resolvesAt);\n  const defenderWounded = recordLanArcadeHospitalWounded(database, combat.defenderLosses, resolvesAt);\n\n  removeCombatLosses(database, combat.defenderLosses);",
        1,
    )
    resolver = resolver.replace(
        "    defenders,\n    combat,\n  });",
        "    defenders,\n    combat,\n    attackerWounded,\n    defenderWounded,\n  });",
        1,
    )
    resolver = resolver.replace(
        "  const combat = resolveLanArcadeCombat('raid', troops, defenders);\n\n  removeCombatLosses(database, combat.defenderLosses);",
        "  const combat = resolveLanArcadeCombat('raid', troops, defenders);\n  const attackerWounded = recordLanArcadeHospitalWounded(database, combat.attackerLosses, resolvesAt);\n  const defenderWounded = recordLanArcadeHospitalWounded(database, combat.defenderLosses, resolvesAt);\n\n  removeCombatLosses(database, combat.defenderLosses);",
        1,
    )
    resolver = resolver.replace(
        "    combat,\n    carriedResources,",
        "    combat,\n    attackerWounded,\n    defenderWounded,\n    carriedResources,",
        1,
    )
resolver_path.write_text(resolver)

query_keys_path = root / 'apps/web/app/(game)/constants/query-keys.ts'
query_keys = query_keys_path.read_text()
if "hospitalWoundedTroopsCacheKey" not in query_keys:
    query_keys = query_keys.replace(
        "export const troopMovementsCacheKey = 'troop-movements';",
        "export const troopMovementsCacheKey = 'troop-movements';\nexport const hospitalWoundedTroopsCacheKey = 'hospital-wounded-troops';",
        1,
    )
query_keys_path.write_text(query_keys)

hospital_ui = r'''import { use, useMemo } from 'react';
import { useMutation, useSuspenseQuery } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { getUnitDefinition } from '@pillage-first/game-assets/utils/units';
import { Bookmark } from 'app/(game)/(village-slug)/(village)/(...building-field-id)/components/components/bookmark';
import { useCurrentVillage } from 'app/(game)/(village-slug)/hooks/current-village/use-current-village';
import {
  Section,
  SectionContent,
} from 'app/(game)/(village-slug)/components/building-layout';
import {
  effectsCacheKey,
  hospitalWoundedTroopsCacheKey,
  villageTroopsCacheKey,
} from 'app/(game)/constants/query-keys';
import { ApiContext } from 'app/(game)/providers/api-provider';
import { Icon } from 'app/components/icon';
import { unitIdToUnitIconMapper } from 'app/components/icons/icons';
import { Text } from 'app/components/text';
import { Alert } from 'app/components/ui/alert';
import { Button } from 'app/components/ui/button';
import {
  Table,
  TableBody,
  TableCell,
  TableHeader,
  TableHeaderCell,
  TableRow,
} from 'app/components/ui/table';
import { invalidateQueries } from 'app/utils/react-query';

const formatResources = (resources: number[]) => {
  const labels = ['wood', 'clay', 'iron', 'wheat'];
  return resources
    .map((amount, index) => `${Math.round(amount)} ${labels[index]}`)
    .join(', ');
};

export const HospitalTroopTraining = () => {
  const { t } = useTranslation();
  const { apiClient } = use(ApiContext);
  const { currentVillage } = useCurrentVillage();

  const { data: woundedTroops } = useSuspenseQuery({
    queryKey: [hospitalWoundedTroopsCacheKey, currentVillage.id],
    queryFn: async () => {
      const { data } = await apiClient.get(
        '/villages/:villageId/hospital/wounded-troops',
        { path: { villageId: currentVillage.id } },
      );
      return data;
    },
  });

  const totalWounded = useMemo(
    () => woundedTroops.reduce((sum, troop) => sum + troop.amount, 0),
    [woundedTroops],
  );

  const { mutate: healWoundedTroops, isPending, error } = useMutation({
    mutationFn: async ({ unitId, amount }: { unitId: string; amount: number }) => {
      await apiClient.post('/villages/:villageId/hospital/heal', {
        path: { villageId: currentVillage.id },
        body: { unitId, amount } as never,
      });
    },
    onSuccess: async (_data, _vars, _onMutateResult, context) => {
      await invalidateQueries(context, [
        [hospitalWoundedTroopsCacheKey, currentVillage.id],
        [villageTroopsCacheKey, currentVillage.id],
        [effectsCacheKey, currentVillage.id],
      ]);
    },
  });

  return (
    <Section>
      <SectionContent>
        <Bookmark tab="train" />
        <Text as="h2">{t('Hospital')}</Text>
        <Text>
          {t(
            'A village with a Hospital recovers roughly 40% of eligible infantry and cavalry losses from battle as wounded troops. Healing costs the same resources as training and returns units immediately in this LAN build.',
          )}
        </Text>
        <Text as="h3">{t('Wounded troops')}</Text>
        {totalWounded > 0 ? (
          <Text>
            {t('{{count}} wounded troops can be healed in this village.', {
              count: totalWounded,
            })}
          </Text>
        ) : (
          <Alert variant="warning">
            {t(
              'No wounded troops are waiting here. Only losses from this village while it has a Hospital become wounded.',
            )}
          </Alert>
        )}
        {error ? (
          <Alert variant="destructive">{error.message}</Alert>
        ) : null}
      </SectionContent>

      <SectionContent>
        <div className="scrollbar-hidden overflow-x-auto">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHeaderCell>{t('Unit')}</TableHeaderCell>
                <TableHeaderCell>{t('Wounded')}</TableHeaderCell>
                <TableHeaderCell>{t('Heal all cost')}</TableHeaderCell>
                <TableHeaderCell>{t('Actions')}</TableHeaderCell>
              </TableRow>
            </TableHeader>
            <TableBody>
              {woundedTroops.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={4}>
                    <Text>{t('No units are currently wounded.')}</Text>
                  </TableCell>
                </TableRow>
              ) : (
                woundedTroops.map((troop) => {
                  const unit = getUnitDefinition(troop.unitId);
                  return (
                    <TableRow key={troop.unitId}>
                      <TableCell>
                        <span className="inline-flex items-center gap-2">
                          <Icon
                            className="size-5"
                            type={unitIdToUnitIconMapper(troop.unitId)}
                          />
                          {t(`UNITS.${troop.unitId}.NAME`, { count: troop.amount })}
                        </span>
                      </TableCell>
                      <TableCell>{troop.amount}</TableCell>
                      <TableCell>{formatResources(troop.healCost)}</TableCell>
                      <TableCell>
                        <div className="flex flex-wrap gap-2">
                          <Button
                            size="sm"
                            variant="outline"
                            disabled={isPending}
                            onClick={() => healWoundedTroops({ unitId: troop.unitId, amount: 1 })}
                          >
                            {t('Heal 1')}
                          </Button>
                          <Button
                            size="sm"
                            variant="confirm"
                            disabled={isPending}
                            onClick={() => healWoundedTroops({ unitId: troop.unitId, amount: troop.amount })}
                          >
                            {t('Heal all')}
                          </Button>
                        </div>
                        <Text className="mt-1 text-xs text-muted-foreground">
                          {t('{{crop}} crop upkeep restored when healed.', {
                            crop: unit.unitWheatConsumption,
                          })}
                        </Text>
                      </TableCell>
                    </TableRow>
                  );
                })
              )}
            </TableBody>
          </Table>
        </div>
        <Text className="text-sm text-muted-foreground">
          {t('Siege engines, settlers, chiefs and heroes cannot become wounded.')}
        </Text>
      </SectionContent>
    </Section>
  );
};
'''
ui_path = next(root.glob('apps/web/app/**/hospital-troop-training.tsx'))
ui_path.write_text(hospital_ui)
PY

python3 - <<'PY'
from pathlib import Path
root = Path('.')

# LAN Arcade map usability patch: show the newest saved raid/attack report for
# occupied village tiles directly in the map hover tooltip. This uses existing
# persistent reports, so older player saves keep their history.
tile_tooltip = root / 'apps/web/app/(game)/(village-slug)/(map)/components/tile-tooltip.tsx'
s = tile_tooltip.read_text()
if 'TileTooltipLastPlayerAction' not in s:
    s = s.replace(
        "import { Suspense } from 'react';\n",
        "import { Suspense, useMemo } from 'react';\n",
        1,
    )
    s = s.replace(
        "import type { MapMarker } from '@pillage-first/types/models/map-marker';\n",
        "import type { MapMarker } from '@pillage-first/types/models/map-marker';\n"
        "import type { Report } from '@pillage-first/types/models/report';\n",
        1,
    )
    s = s.replace(
        "import { useReputations } from 'app/(game)/(village-slug)/hooks/use-reputations';\n",
        "import { useReputations } from 'app/(game)/(village-slug)/hooks/use-reputations';\n"
        "import { useReports } from 'app/(game)/(village-slug)/hooks/use-reports';\n",
        1,
    )
    s = s.replace(
        """const TileTooltipResources = ({ tile }: TileTooltipResourcesProps) => {
  const resources = parseResourcesFromRFC(
    tile.attributes.resourceFieldComposition,
  );

  return (
    <div className=\"flex gap-2\">
      <Resources
        iconClassName=\"size-4\"
        resources={resources}
      />
    </div>
  );
};
""",
        """const TileTooltipResources = ({ tile }: TileTooltipResourcesProps) => {
  const resources = parseResourcesFromRFC(
    tile.attributes.resourceFieldComposition,
  );

  return (
    <div className=\"flex gap-2\">
      <Resources
        iconClassName=\"size-4\"
        resources={resources}
      />
    </div>
  );
};

const formatLastActionTimestamp = (timestamp: number) => {
  const timestampMs = timestamp < 10_000_000_000 ? timestamp * 1000 : timestamp;
  return new Date(timestampMs).toLocaleString(undefined, {
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
};

const isVillageActionReport = (report: Report) => {
  return report.type === 'raid' || report.type === 'attack';
};

const isReportForTile = (report: Report, coordinates: string) => {
  return (
    isVillageActionReport(report) &&
    (report.title.includes(coordinates) || report.body.includes(coordinates))
  );
};

const TileTooltipLastPlayerAction = ({
  tile,
}: {
  tile: OccupiedOccupiableTile;
}) => {
  const { t } = useTranslation();
  const { reports } = useReports();
  const coordinates = `(${tile.coordinates.x}|${tile.coordinates.y})`;
  const report = useMemo(
    () => reports.find((report) => isReportForTile(report, coordinates)),
    [coordinates, reports],
  );

  if (!report) {
    return null;
  }

  const label = report.type === 'raid' ? t('Last raid') : t('Last attack');

  return (
    <div className=\"flex flex-col gap-0.5 border-t border-border py-1 text-xs\">
      <span>
        <span className=\"text-gray-300\">{label}</span> -{' '}
        {formatLastActionTimestamp(report.timestamp)}
      </span>
      <span className=\"text-gray-300\">{report.title}</span>
    </div>
  );
};
""",
        1,
    )
    s = s.replace(
        """      <TileTooltipResources tile={tile} />
      <TileTooltipPlayerInfo tile={tile} />
      {!!worldItem && (
""",
        """      <TileTooltipResources tile={tile} />
      <TileTooltipPlayerInfo tile={tile} />
      <TileTooltipLastPlayerAction tile={tile} />
      {!!worldItem && (
""",
        1,
    )
    if 'TileTooltipLastPlayerAction' not in s or 'Last raid' not in s:
        raise SystemExit('Failed to patch last raid/attack tooltip')
    tile_tooltip.write_text(s)
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
