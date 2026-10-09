package com.follow.clash.service.models

import com.follow.clash.common.AccessControlMode
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class TunEndpointTest {
    private fun options(ipv6: Boolean, dnsHijacking: Boolean) = VpnOptions(
        enable = true,
        port = 7890,
        ipv6 = ipv6,
        dnsHijacking = dnsHijacking,
        accessControlProps = AccessControlProps(
            enable = false,
            mode = AccessControlMode.ACCEPT_SELECTED,
            acceptList = emptyList(),
            rejectList = emptyList(),
        ),
        allowBypass = false,
        systemProxy = true,
        bypassDomain = emptyList(),
        stack = "gvisor",
        routeAddress = emptyList(),
    )

    @Test
    fun `an ipv4 tunnel offers the ipv4 address alone`() {
        assertEquals("172.19.0.1/30", options(ipv6 = false, dnsHijacking = false).tunAddress)
    }

    @Test
    fun `an ipv6 tunnel offers both addresses`() {
        assertEquals(
            "172.19.0.1/30,fdfe:dcba:9876::1/126",
            options(ipv6 = true, dnsHijacking = false).tunAddress,
        )
    }

    @Test
    fun `every advertised address parses the way the builder parses it`() {
        val addresses = options(ipv6 = true, dnsHijacking = false).tunAddress.split(",")

        for (address in addresses) {
            assertTrue(address.toCIDR().prefixLength in 0..128)
        }
    }

    @Test
    fun `a hijacking tunnel asks the core for any dns`() {
        assertEquals("0.0.0.0", options(ipv6 = false, dnsHijacking = true).tunDns)
        assertEquals("0.0.0.0", options(ipv6 = true, dnsHijacking = true).tunDns)
    }

    @Test
    fun `a plain tunnel offers the private dns servers`() {
        assertEquals("172.19.0.2", options(ipv6 = false, dnsHijacking = false).tunDns)
        assertEquals(
            "172.19.0.2,fdfe:dcba:9876::2",
            options(ipv6 = true, dnsHijacking = false).tunDns,
        )
    }
}
