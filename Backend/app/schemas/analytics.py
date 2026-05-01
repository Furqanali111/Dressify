from pydantic import BaseModel


class WornItem(BaseModel):
    id:        str
    name:      str
    type:      str
    wear_count: int
    processed_url: str = ""


class WeeklyFrequency(BaseModel):
    week: str   # ISO week label e.g. "2026-W17"
    count: int


class WardrobeAnalyticsResponse(BaseModel):
    total_items:        int
    total_outfits:      int
    most_worn:          list[WornItem]
    underutilised:      list[WornItem]
    color_distribution: dict[str, int]
    style_breakdown:    dict[str, int]
    outfit_frequency:   list[WeeklyFrequency]
