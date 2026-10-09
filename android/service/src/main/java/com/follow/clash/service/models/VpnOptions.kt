package com.follow.clash.service.models

import com.follow.clash.common.AccessControlMode
import java.net.Inet4Address
import java.net.Inet6Address
import java.net.InetAddress

data class AccessControlProps(
    val enable: Boolean,
    val mode: AccessControlMode,
    val acceptList: List<String>,
    val rejectList: List<String>,
)

data class VpnOptions(
    val enable: Boolean,
    val port: Int,
    val ipv6: Boolean,
    val dnsHijacking: Boolean,
    val accessControlProps: AccessControlProps,
    val allowBypass: Boolean,
    val systemProxy: Boolean,
    val bypassDomain: List<String>,
    val stack: String,
    val routeAddress: List<String>,
)

data class CIDR(
    val address: InetAddress,
    val prefixLength: Int,
)

internal const val IPV4_ADDRESS = "172.19.0.1/30"
internal const val IPV6_ADDRESS = "fdfe:dcba:9876::1/126"
internal const val DNS = "172.19.0.2"
internal const val DNS6 = "fdfe:dcba:9876::2"
internal const val NET_ANY = "0.0.0.0"
internal const val NET_ANY6 = "::"

// The Core builds its tun from these two strings, so they stay in step with the
// addresses and DNS servers the VpnService.Builder is given.
internal val VpnOptions.tunAddress: String
    get() = buildString {
        append(IPV4_ADDRESS)
        if (ipv6) {
            append(",")
            append(IPV6_ADDRESS)
        }
    }

internal val VpnOptions.tunDns: String
    get() {
        if (dnsHijacking) {
            return NET_ANY
        }
        return buildString {
            append(DNS)
            if (ipv6) {
                append(",")
                append(DNS6)
            }
        }
    }

fun VpnOptions.getIpv4RouteAddress(): List<CIDR> = routeAddress
    .map(String::toCIDR)
    .filter { it.address is Inet4Address }

fun VpnOptions.getIpv6RouteAddress(): List<CIDR> = routeAddress
    .map(String::toCIDR)
    .filter { it.address is Inet6Address }

fun String.toCIDR(): CIDR {
    val parts = split("/")
    require(parts.size == 2) { "Invalid CIDR format: $this" }
    val ipAddress = parts[0]
    val prefixLength = parts[1].toIntOrNull()
        ?: throw IllegalArgumentException("Invalid prefix length: ${parts[1]}")

    val address = InetAddress.getByName(ipAddress)
    val maxPrefix = if (address.address.size == 4) 32 else 128
    require(prefixLength in 0..maxPrefix) {
        "Invalid prefix length $prefixLength for $ipAddress"
    }

    return CIDR(address, prefixLength)
}
