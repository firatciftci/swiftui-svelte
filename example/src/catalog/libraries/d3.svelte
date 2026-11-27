<script lang="ts">
  import { scaleBand, scaleLinear } from "d3-scale";
  import { arc, area, curveMonotoneX, line, pie } from "d3-shape";

  type Month = { month: string; sales: number };

  const months: Array<Month> = [
    { month: "Jan", sales: 32 },
    { month: "Feb", sales: 45 },
    { month: "Mar", sales: 38 },
    { month: "Apr", sales: 61 },
    { month: "May", sales: 54 },
    { month: "Jun", sales: 72 },
  ];
  const width = 320;
  const height = 200;
  const margin = { top: 12, right: 12, bottom: 24, left: 32 };

  let scale = $state(1);
  const data = $derived(months.map((d) => ({ ...d, sales: d.sales * scale })));
  const x = $derived(
    scaleBand<string>()
      .domain(months.map((d) => d.month))
      .range([margin.left, width - margin.right])
      .padding(0.25),
  );
  const y = $derived(
    scaleLinear()
      .domain([0, 100])
      .range([height - margin.bottom, margin.top]),
  );
  const center = (d: Month) => (x(d.month) ?? 0) + x.bandwidth() / 2;
  const trend = $derived(
    line<Month>()
      .x(center)
      .y((d) => y(d.sales))
      .curve(curveMonotoneX)(data) ?? "",
  );
  const fill = $derived(
    area<Month>()
      .x(center)
      .y0(y(0))
      .y1((d) => y(d.sales))
      .curve(curveMonotoneX)(data) ?? "",
  );

  const shares = [
    { name: "Web", value: 5, color: "steelblue" },
    { name: "iOS", value: 3, color: "tomato" },
    { name: "Android", value: 2, color: "goldenrod" },
  ];
  const slices = pie<(typeof shares)[number]>().value((d) => d.value)(shares);
  const slice = arc<(typeof slices)[number]>().innerRadius(40).outerRadius(80);
</script>

<scrollview>
  <vstack spacing={16} padding>
    <svg
      {width}
      {height}
      viewBox="0 0 {width} {height}"
      aria-label="Monthly sales"
    >
      {#each y.ticks(5) as tick (tick)}
        <g transform="translate(0, {y(tick)})">
          <line
            x1={margin.left}
            x2={width - margin.right}
            stroke="gray"
            stroke-opacity="0.3"
          />
          <text
            x={margin.left - 6}
            dy="0.32em"
            text-anchor="end"
            font-size="10"
            fill="gray">{tick}</text
          >
        </g>
      {/each}
      <path d={fill} fill="steelblue" fill-opacity="0.15" />
      {#each data as d (d.month)}
        <rect
          x={x(d.month)}
          y={y(d.sales)}
          width={x.bandwidth()}
          height={y(0) - y(d.sales)}
          rx="3"
          fill="steelblue"
        />
        <text
          x={center(d)}
          y={height - 8}
          text-anchor="middle"
          font-size="10"
          fill="currentColor"
        >
          {d.month}
        </text>
      {/each}
      <path
        d={trend}
        fill="none"
        stroke="tomato"
        stroke-width="2"
        stroke-linecap="round"
      />
      {#each data as d (d.month)}
        <circle
          cx={center(d)}
          cy={y(d.sales)}
          r="3"
          fill="white"
          stroke="tomato"
          stroke-width="2"
        />
      {/each}
    </svg>
    <btn variant="bordered" onclick={() => (scale = scale === 1 ? 0.6 : 1)}>
      Change the data
    </btn>
    <svg
      width="200"
      height="200"
      viewBox="-100 -100 200 200"
      aria-label="Users by platform"
    >
      {#each slices as d (d.data.name)}
        <path
          d={slice(d)}
          fill={d.data.color}
          stroke="white"
          stroke-width="2"
        />
        <text
          transform="translate({slice.centroid(d).join(',')})"
          text-anchor="middle"
          dominant-baseline="middle"
          font-size="11"
          font-weight="600"
          fill="white"
        >
          {d.data.name}
        </text>
      {/each}
    </svg>
  </vstack>
</scrollview>
