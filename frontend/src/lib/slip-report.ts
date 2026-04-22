export type FormulaGroupKey = "1k" | "2k" | "3k"

export type FormulaDetail = {
  formula: string
  total_thickness: number | null
}

export type SlipLookupResponse = {
  status: "success" | "not_found"
  message?: string
  width: number
  height: number
  width_round: number
  height_round: number
  marking: string | null
  formulas: Record<FormulaGroupKey, string[]>
  formula_details: Record<FormulaGroupKey, FormulaDetail[]>
}

export const formulaGroups: Array<{ key: FormulaGroupKey; title: string }> = [
  { key: "1k", title: "1-камерные" },
  { key: "2k", title: "2-камерные" },
  { key: "3k", title: "3-камерные" },
]

export const visibleFormulaGroups = formulaGroups.filter(({ key }) => key !== "3k")

export function splitMarkingLines(marking: string | null) {
  if (!marking) {
    return []
  }

  return marking
    .split(/\s+/)
    .map((part) => part.trim())
    .filter(Boolean)
}

export function formatFormulaWithThickness(formulaDetail: FormulaDetail) {
  return formulaDetail.formula
}

function extractFormulaSegments(formula: string) {
  const normalized = formula
    .trim()
    .replace(/\s+/g, "")
    .replace(/[^0-9-]/g, "")

  if (!normalized) {
    return []
  }

  return normalized
    .split("-")
    .map((part) => part.trim())
    .filter(Boolean)
    .map((part) => Number(part))
    .filter((part) => Number.isFinite(part))
}

export function getFormulaGlassThickness(formula: string) {
  const segments = extractFormulaSegments(formula)
  if (segments.length === 0) {
    return null
  }

  const glassThickness = segments.reduce((sum, value, index) => {
    return index % 2 === 0 ? sum + value : sum
  }, 0)

  return glassThickness > 0 ? glassThickness : null
}

export function calculateFormulaWeightKg(formula: string, width: number, height: number) {
  const glassThickness = getFormulaGlassThickness(formula)
  if (glassThickness == null || width <= 0 || height <= 0) {
    return null
  }

  return (width / 1000) * (height / 1000) * glassThickness * 2.5
}

function formatNumber(value: number) {
  return new Intl.NumberFormat("ru-RU", {
    minimumFractionDigits: 0,
    maximumFractionDigits: 2,
  }).format(value)
}

export function formatFormulaSummary(
  formulaDetail: FormulaDetail,
  dimensions?: { width: number; height: number },
) {
  const parts: string[] = []

  if (formulaDetail.total_thickness != null) {
    parts.push(`${formulaDetail.total_thickness}мм`)
  }

  if (dimensions) {
    const weight = calculateFormulaWeightKg(formulaDetail.formula, dimensions.width, dimensions.height)
    if (weight != null) {
      parts.push(`${formatNumber(weight)}кг`)
    }
  }

  return parts.length > 0
    ? `${formulaDetail.formula} (${parts.join("; ")})`
    : formulaDetail.formula
}

export function formatSearchResultText(result: SlipLookupResponse | null, error: string | null) {
  if (error) {
    return `ПОДБОР ФОРМУЛЫ\nОшибка: ${error}`
  }

  if (!result) {
    return ""
  }

  const lines = [
    "ПОДБОР ФОРМУЛЫ",
    `Размер: ${result.width}x${result.height}`,
    `Округление: ${result.width_round}x${result.height_round}`,
  ]

  const markingLines = splitMarkingLines(result.marking)
  if (markingLines.length > 0) {
    lines.push("Формулы из таблицы слипания:")
    markingLines.forEach((line) => lines.push(line))
  }

  if (result.status === "not_found") {
    lines.push("Результат: правило в таблице слипания не найдено")
    return lines.join("\n")
  }

  lines.push("Результат: формулы найдены")

  visibleFormulaGroups.forEach(({ key, title }) => {
    const values = result.formula_details[key] || []
    if (values.length > 0) {
      lines.push(`${title}:`)
      values.forEach((formulaDetail) =>
        lines.push(
          formatFormulaSummary(formulaDetail, {
            width: result.width,
            height: result.height,
          }),
        ),
      )
    }
  })

  return lines.join("\n")
}
