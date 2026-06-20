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
if not report_list.exists():
    report_list.write_text("""import { useTranslation } from 'react-i18next';
import type { Report } from '@pillage-first/types/models/report';
import { Text } from 'app/components/text';
import { Alert } from 'app/components/ui/alert';
import {
  Table,
  TableBody,
  TableCell,
  TableHeader,
  TableHeaderCell,
  TableRow,
} from 'app/components/ui/table';

type ReportListProps = {
  reports: Report[];
};

const formatTimestamp = (timestamp: number) => {
  return new Date(timestamp).toLocaleString();
};

export const ReportList = ({ reports }: ReportListProps) => {
  const { t } = useTranslation();

  if (reports.length === 0) {
    return <Alert variant="info">{t('No reports yet')}</Alert>;
  }

  return (
    <div className="w-full overflow-x-auto">
      <Table className="min-w-[760px]">
        <TableHeader>
          <TableRow>
            <TableHeaderCell>{t('Time')}</TableHeaderCell>
            <TableHeaderCell>{t('Type')}</TableHeaderCell>
            <TableHeaderCell>{t('Report')}</TableHeaderCell>
            <TableHeaderCell>{t('Village')}</TableHeaderCell>
            <TableHeaderCell>{t('Tags')}</TableHeaderCell>
          </TableRow>
        </TableHeader>
        <TableBody>
          {reports.map((report) => (
            <TableRow key={report.id}>
              <TableCell className="whitespace-nowrap text-left">
                {formatTimestamp(report.timestamp)}
              </TableCell>
              <TableCell className="capitalize">{report.type}</TableCell>
              <TableCell className="text-left">
                <Text className="font-semibold">{report.title}</Text>
                <Text className="text-sm text-muted-foreground">
                  {report.body}
                </Text>
              </TableCell>
              <TableCell>{report.villageId}</TableCell>
              <TableCell>
                {report.tags.length > 0 ? report.tags.join(', ') : t('New')}
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
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

  const pagination = usePagination(filteredReports, 20, page);

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

  const pagination = usePagination(filteredReports, 20, page);

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

  const pagination = usePagination(filteredReports, 20, page);

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
