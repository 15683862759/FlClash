package main

import "testing"

// The table normalizeRegion searches is packed by hand, so its length, casing and order are part of its contract.
func TestISO3166PackedTableShape(t *testing.T) {
	if len(iso3166Packed)%5 != 0 {
		t.Fatalf("packed table length %d is not a multiple of 5", len(iso3166Packed))
	}
	if entries := len(iso3166Packed) / 5; entries != 249 {
		t.Fatalf("packed table holds %d entries, want the 249 ISO 3166-1 alpha-3 codes", entries)
	}
	previous := ""
	for index := 0; index < len(iso3166Packed); index += 5 {
		alpha3 := iso3166Packed[index : index+3]
		alpha2 := iso3166Packed[index+3 : index+5]
		if !isAsciiUpper(alpha3) || !isAsciiUpper(alpha2) {
			t.Fatalf(
				"entry %d is not upper case ASCII: %q",
				index/5,
				iso3166Packed[index:index+5],
			)
		}
		if previous >= alpha3 {
			t.Fatalf("table is not sorted by alpha-3: %q follows %q", alpha3, previous)
		}
		previous = alpha3
	}
}

func TestNormalizeRegionReachesEveryEntry(t *testing.T) {
	for index := 0; index < len(iso3166Packed); index += 5 {
		alpha3 := iso3166Packed[index : index+3]
		alpha2 := iso3166Packed[index+3 : index+5]
		if got := normalizeRegion(alpha3); got != alpha2 {
			t.Errorf("normalizeRegion(%q) = %q, want %q", alpha3, got, alpha2)
		}
	}
}
