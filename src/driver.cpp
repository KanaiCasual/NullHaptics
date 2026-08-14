// NullHaptics — SteamVR add-on driver that silences all controller haptics globally.
//
// Every haptic request from a game (OpenVR, or OpenXR via SteamVR) reaches the owning
// controller driver (driver_lighthouse for Index knuckles) as a
// VREvent_Input_HapticVibration event pulled from IVRServerDriverHost::PollNextEvent.
// All drivers share one vrserver.exe process and one host vtable, so this driver
// inline-hooks PollNextEvent and forces every haptic pulse's amplitude to zero before
// the owning driver can drive the physical actuator.

#include <openvr_driver.h>
#include <MinHook.h>

#include <atomic>
#include <cstring>

using namespace vr;

namespace
{

// Vtable index of PollNextEvent in IVRServerDriverHost_006:
// 0 TrackedDeviceAdded, 1 TrackedDevicePoseUpdated, 2 VsyncEvent,
// 3 VendorSpecificEvent, 4 IsExiting, 5 PollNextEvent, ...
constexpr size_t k_PollNextEventVtableIndex = 5;

using PollNextEventFn = bool ( * )( void *thisptr, VREvent_t *pEvent, uint32_t uncbVREvent );

PollNextEventFn g_origPollNextEvent = nullptr;
std::atomic<uint64_t> g_zeroedEvents{ 0 };

// Forces the pulse parameters of every haptic event to zero in place, then lets the
// event flow on — the owning driver runs the actuator at zero amplitude, i.e. silence.
bool PollNextEvent_Hook( void *thisptr, VREvent_t *pEvent, uint32_t uncbVREvent )
{
	bool haveEvent = g_origPollNextEvent( thisptr, pEvent, uncbVREvent );
	if ( haveEvent && pEvent->eventType == VREvent_Input_HapticVibration
		&& uncbVREvent >= sizeof( VREvent_t ) )
	{
		VREvent_HapticVibration_t &h = pEvent->data.hapticVibration;
		if ( h.fAmplitude != 0.0f || h.fDurationSeconds != 0.0f )
		{
			h.fAmplitude = 0.0f;
			h.fDurationSeconds = 0.0f;
			h.fFrequency = 0.0f;
			g_zeroedEvents.fetch_add( 1, std::memory_order_relaxed );
		}
	}
	return haveEvent;
}

class NullHapticsProvider : public IServerTrackedDeviceProvider
{
public:
	EVRInitError Init( IVRDriverContext *pDriverContext ) override
	{
		VR_INIT_SERVER_DRIVER_CONTEXT( pDriverContext );

		EVRSettingsError settingsErr = VRSettingsError_None;
		bool enabled = VRSettings()->GetBool( "driver_NullHaptics", "enabled", &settingsErr );
		if ( settingsErr != VRSettingsError_None )
			enabled = true;
		if ( !enabled )
		{
			VRDriverLog()->Log( "NullHaptics: disabled via steamvr.vrsettings (driver_NullHaptics/enabled = false)." );
			return VRInitError_None;
		}

		IVRServerDriverHost *host = VRServerDriverHost();
		if ( !host )
			return VRInitError_Init_InterfaceNotFound;

		void **vtable = *reinterpret_cast<void ***>( host );
		void *target = vtable[k_PollNextEventVtableIndex];

		if ( MH_Initialize() != MH_OK )
		{
			VRDriverLog()->Log( "NullHaptics: MH_Initialize failed." );
			return VRInitError_None; // never take SteamVR down over this
		}
		if ( MH_CreateHook( target, reinterpret_cast<void *>( &PollNextEvent_Hook ),
				reinterpret_cast<void **>( &g_origPollNextEvent ) ) != MH_OK
			|| MH_EnableHook( target ) != MH_OK )
		{
			VRDriverLog()->Log( "NullHaptics: failed to hook IVRServerDriverHost::PollNextEvent." );
			MH_Uninitialize();
			return VRInitError_None;
		}

		m_hooked = true;
		VRDriverLog()->Log( "NullHaptics: PollNextEvent hooked — all haptic vibration amplitude forced to 0." );
		return VRInitError_None;
	}

	void Cleanup() override
	{
		if ( m_hooked )
		{
			char msg[128];
			snprintf( msg, sizeof( msg ), "NullHaptics: shutting down, zeroed %llu haptic events this session.",
				static_cast<unsigned long long>( g_zeroedEvents.load() ) );
			VRDriverLog()->Log( msg );
			MH_DisableHook( MH_ALL_HOOKS );
			MH_Uninitialize();
			m_hooked = false;
		}
		VR_CLEANUP_SERVER_DRIVER_CONTEXT();
	}

	const char *const *GetInterfaceVersions() override { return k_InterfaceVersions; }
	void RunFrame() override {}
	bool ShouldBlockStandbyMode() override { return false; }
	void EnterStandby() override {}
	void LeaveStandby() override {}

private:
	bool m_hooked = false;
};

NullHapticsProvider g_provider;

} // namespace

extern "C" __declspec( dllexport ) void *HmdDriverFactory( const char *pInterfaceName, int *pReturnCode )
{
	if ( 0 == strcmp( IServerTrackedDeviceProvider_Version, pInterfaceName ) )
		return &g_provider;
	if ( pReturnCode )
		*pReturnCode = VRInitError_Init_InterfaceNotFound;
	return nullptr;
}
