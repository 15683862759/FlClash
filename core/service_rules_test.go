package main

import (
	"context"
	"net/http"
	"testing"
	"time"
)

func TestNormalizeRegion(t *testing.T) {
	cases := map[string]string{
		"US":    "US",
		"jp":    "JP",
		"CHN":   "CN",
		"usa":   "US",
		"HKG":   "HK",
		"ZZZ":   "",
		"C":     "",
		"CNAAA": "",
		"":      "",
		"1A":    "",
	}
	for input, want := range cases {
		if got := normalizeRegion(input); got != want {
			t.Errorf("normalizeRegion(%q) = %q, want %q", input, got, want)
		}
	}
}

func TestNormalizeRegionCoversTheBlockLists(t *testing.T) {
	for _, code := range geminiBlockedRegions {
		if normalizeRegion(code) == "" {
			t.Errorf("gemini block list entry %q does not fold to an alpha-2 code", code)
		}
	}
	for _, code := range claudeBlockedRegions {
		if normalizeRegion(code) != code {
			t.Errorf("claude block list entry %q is not already alpha-2", code)
		}
	}
}

// The iOS endpoint turns API clients away even where ChatGPT works, so that
// refusal is the success signal and anything else is not.
func TestChatGptIosStatus(t *testing.T) {
	cases := map[string]string{
		"Request is not allowed. Please try again later.": serviceAvailable,
		"You may be connected to a disallowed ISP":        serviceDisallowedIsp,
		"Sorry, you have been blocked":                    serviceBlocked,
		"<html>something else entirely</html>":            serviceFailed,
		"":                                                serviceFailed,
	}
	for body, want := range cases {
		if got := chatGptIosStatus(&ProbeResult{Body: body}); got != want {
			t.Errorf("chatGptIosStatus(%q) = %q, want %q", body, got, want)
		}
	}
}

func TestTikTokStatus(t *testing.T) {
	cases := []struct {
		code int
		body string
		want string
	}{
		{http.StatusOK, `{"region":"JP"}`, serviceAvailable},
		{http.StatusForbidden, "", serviceUnsupportedRegion},
		{http.StatusUnavailableForLegalReasons, "", serviceUnsupportedRegion},
		{http.StatusOK, "Access Denied", serviceUnsupportedRegion},
		{http.StatusOK, "TikTok is not available in your region", serviceUnsupportedRegion},
		{http.StatusInternalServerError, "", serviceFailed},
	}
	for _, testCase := range cases {
		got := tikTokStatus(&ProbeResult{StatusCode: testCase.code, Body: testCase.body})
		if got != testCase.want {
			t.Errorf("tikTokStatus(%d, %q) = %q, want %q", testCase.code, testCase.body, got, testCase.want)
		}
	}
}

func TestTikTokRegionReadsTheAppContext(t *testing.T) {
	const cluster = `{"idc":"no1a","vdc":"no1a","region":"EU-TTP2","vregion":"EU-TTP2"}`
	page := cluster + `{"__DEFAULT_SCOPE__":{"webapp.app-context":{"language":"en","region":"GB","appId":1233}}}`
	if got := tikTokRegion(page); got != "GB" {
		t.Errorf("region = %q, want the visitor's country rather than the serving cluster", got)
	}
	if got := tikTokRegion(cluster); got != "" {
		t.Errorf("region = %q, want empty without the app context", got)
	}
	if got := tikTokRegion(`{"webapp.app-context":{"region":"zh-Hant-TW"}}`); got != "" {
		t.Errorf("region = %q, want a locale left unread rather than its language", got)
	}
}

func TestSpotifyRegionPrefersTheRedirectedPath(t *testing.T) {
	redirected := &ProbeResult{Url: "https://www.spotify.com/de-de/", Body: `{"countryCode":"US"}`}
	if got := spotifyRegion(redirected); got != "de" {
		t.Errorf("region = %q, want the path's country", got)
	}
	unredirected := &ProbeResult{
		Url:  "https://www.spotify.com/api/content/v1/country-selector",
		Body: `{"countryCode":"SE"}`,
	}
	if got := spotifyRegion(unredirected); got != "SE" {
		t.Errorf("region = %q, want the payload's country", got)
	}
}

func TestYouTubeRegionPatterns(t *testing.T) {
	bodies := map[string]string{
		`<span id="country-code"> GB </span>`: "GB",
		`{"GL":"JP","other":1}`:               "JP",
		`{"countryCode":"KR"}`:                "KR",
		`{"country_code":"BR"}`:               "BR",
	}
	for body, want := range bodies {
		var got string
		for _, pattern := range youTubeRegionPatterns {
			if code := firstSubmatch(pattern, body); code != "" {
				got = normalizeRegion(code)
				break
			}
		}
		if got != want {
			t.Errorf("region from %q = %q, want %q", body, got, want)
		}
	}
}

func TestDisneyAndPrimePatterns(t *testing.T) {
	if got := firstSubmatch(disneyAssertionPattern, `{"assertion":"abc.def"}`); got != "abc.def" {
		t.Errorf("assertion = %q", got)
	}
	if got := firstSubmatch(disneyRefreshPattern, `{"refresh_token":"tok123"}`); got != "tok123" {
		t.Errorf("refresh token = %q", got)
	}
	if got := firstSubmatch(disneySupportedPattern, `{"inSupportedLocation":false}`); got != "false" {
		t.Errorf("supported = %q", got)
	}
	if got := firstSubmatch(primeRegionPattern, `{"currentTerritory":"NL"}`); got != "NL" {
		t.Errorf("territory = %q", got)
	}
}

func withServiceProbe(t *testing.T, answers map[string]*ProbeResult) {
	t.Helper()
	previous := serviceProbe
	serviceProbe = func(_ context.Context, req probeRequest) *ProbeResult {
		if result, ok := answers[req.url]; ok {
			return result
		}
		return &ProbeResult{Error: probeErrorFailed}
	}
	t.Cleanup(func() { serviceProbe = previous })
}

func runServiceRule(
	t *testing.T,
	answers map[string]*ProbeResult,
	check func(serviceEnv) ServiceCheckItem,
) ServiceCheckItem {
	t.Helper()
	withServiceProbe(t, answers)
	return check(serviceEnv{ctx: context.Background(), timeout: time.Second})
}

func TestCheckReachableMapsTheStatusCode(t *testing.T) {
	withServiceProbe(t, map[string]*ProbeResult{
		"probe://ok":    {StatusCode: http.StatusNoContent, Delay: 12},
		"probe://later": {StatusCode: http.StatusNotFound},
		"probe://block": {StatusCode: http.StatusForbidden},
		"probe://empty": {},
	})
	env := serviceEnv{ctx: context.Background()}

	for url, want := range map[string]string{
		"probe://ok":    serviceAvailable,
		"probe://later": serviceUnavailable,
		"probe://block": serviceRestricted,
		"probe://empty": serviceUnavailable,
	} {
		if got := checkReachable(url)(env); got.Status != want {
			t.Errorf("checkReachable(%q) = %q, want %q", url, got.Status, want)
		}
	}
}

func TestCheckClaudeFollowsTheLocation(t *testing.T) {
	const url = "https://claude.ai/cdn-cgi/trace"

	allowed := runServiceRule(t, map[string]*ProbeResult{
		url: {StatusCode: http.StatusOK, Body: "loc=DE\n", Delay: 30},
	}, checkClaude)
	if allowed.Status != serviceAvailable || allowed.Region != "DE" {
		t.Errorf("loc=DE gave %+v, want available in DE", allowed)
	}

	blocked := runServiceRule(t, map[string]*ProbeResult{
		url: {StatusCode: http.StatusOK, Body: "loc=CN\n"},
	}, checkClaude)
	if blocked.Status != serviceUnsupportedRegion || blocked.Region != "CN" {
		t.Errorf("loc=CN gave %+v, want an unsupported region", blocked)
	}

	for _, body := range []string{"loc=1A\n", "loc=\n"} {
		unreadable := runServiceRule(t, map[string]*ProbeResult{
			url: {StatusCode: http.StatusOK, Body: body},
		}, checkClaude)
		if unreadable.Status != serviceFailed {
			t.Errorf("%q gave %q, want %q", body, unreadable.Status, serviceFailed)
		}
	}

	timedOut := runServiceRule(t, map[string]*ProbeResult{
		url: {Error: probeErrorTimeout, Delay: 900},
	}, checkClaude)
	if timedOut.Status != serviceTimeout || timedOut.Delay != 0 {
		t.Errorf("a timeout gave %+v, want no delay kept", timedOut)
	}
}

func TestCheckGeminiReadsTheRegionCode(t *testing.T) {
	const url = "https://gemini.google.com"
	page := func(code string) *ProbeResult {
		return &ProbeResult{StatusCode: http.StatusOK, Body: `{"x":1}` + geminiRegionMarker + code + `"}`}
	}

	allowed := runServiceRule(t, map[string]*ProbeResult{url: page("DEU")}, checkGemini)
	if allowed.Status != serviceAvailable || allowed.Region != "DE" {
		t.Errorf("DEU gave %+v, want available in DE", allowed)
	}

	blocked := runServiceRule(t, map[string]*ProbeResult{url: page("CHN")}, checkGemini)
	if blocked.Status != serviceUnsupportedRegion {
		t.Errorf("CHN gave %q, want %q", blocked.Status, serviceUnsupportedRegion)
	}

	lowercase := runServiceRule(t, map[string]*ProbeResult{url: page("deu")}, checkGemini)
	if lowercase.Status != serviceFailed {
		t.Errorf("a lowercase code gave %q, want %q", lowercase.Status, serviceFailed)
	}

	missing := runServiceRule(t, map[string]*ProbeResult{
		url: {StatusCode: http.StatusOK, Body: `<html></html>`},
	}, checkGemini)
	if missing.Status != serviceFailed {
		t.Errorf("a page without the marker gave %q, want %q", missing.Status, serviceFailed)
	}
}

func TestCheckYouTubePremiumStatuses(t *testing.T) {
	const url = "https://www.youtube.com/premium?hl=en"

	allowed := runServiceRule(t, map[string]*ProbeResult{
		url: {StatusCode: http.StatusOK, Body: `{"GL":"JP"} <span>ad-free</span>`},
	}, checkYouTubePremium)
	if allowed.Status != serviceAvailable || allowed.Region != "JP" {
		t.Errorf("an ad-free page gave %+v, want available in JP", allowed)
	}

	blocked := runServiceRule(t, map[string]*ProbeResult{
		url: {StatusCode: http.StatusOK, Body: `{"GL":"JP"} YouTube Premium is not available in your country`},
	}, checkYouTubePremium)
	if blocked.Status != serviceUnsupportedRegion {
		t.Errorf("the refusal page gave %q, want %q", blocked.Status, serviceUnsupportedRegion)
	}

	broken := runServiceRule(t, map[string]*ProbeResult{
		url: {StatusCode: http.StatusInternalServerError},
	}, checkYouTubePremium)
	if broken.Status != serviceUnavailable {
		t.Errorf("a 500 gave %q, want %q", broken.Status, serviceUnavailable)
	}
}
