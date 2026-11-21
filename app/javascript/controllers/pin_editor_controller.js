import { Controller } from "@hotwired/stimulus";

// Draggable-pin map for the admin partner form's address section. It starts at
// the geocoded best-guess for the address (or the deployment's default ZIP
// centroid), and writes the pin position back into the latitude/longitude
// inputs so it's submitted with the form. When an address field changes, it
// asks the server for a fresh best-guess and moves the pin there.
export default class extends Controller {
	static values = { args: Object };

	static targets = ["map", "latitude", "longitude"];

	async connect() {
		const { whenVisible } = await import("controllers/mixins/when_visible");
		if (!this.element.isConnected) return;
		this._stopWatching = whenVisible(this.element, () => this._loadMap());

		this._pin = this.argsValue.pin ?? null;
		this._onAddressChange = () => this._lookupAddress();
		this._addressFields = [
			"street_address",
			"street_address2",
			"street_address3",
			"city",
			"postcode",
		]
			.map((name) => this._field(name))
			.filter((field) => field);
		for (const field of this._addressFields) {
			field.addEventListener("change", this._onAddressChange);
		}
	}

	disconnect() {
		this._stopWatching?.();
		for (const field of this._addressFields ?? []) {
			field.removeEventListener("change", this._onAddressChange);
		}
		this.map?.remove();
	}

	async _loadMap() {
		const [, , { ensureMaplibreCss }] = await Promise.all([
			import("leaflet"),
			import("@maplibre/maplibre-gl-leaflet"),
			import("controllers/mixins/map_css"),
		]);
		if (!this.element.isConnected) return;

		ensureMaplibreCss();
		this._createMap();
	}

	_createMap() {
		this.map = L.map(this.mapTarget, { zoomControl: false });
		this.map.attributionControl.setPrefix(false);
		this.map.scrollWheelZoom.disable();
		L.control
			.zoom({
				zoomInTitle: this.argsValue.zoomIn,
				zoomOutTitle: this.argsValue.zoomOut,
			})
			.addTo(this.map);

		L.maplibreGL({
			style: this.argsValue.styleUrl,
			attribution:
				'&copy; <a href="https://openstreetmap.org/copyright">OpenStreetMap</a> contributors',
		})
			.on("add", (e) =>
				e.target.getContainer().setAttribute("aria-hidden", "true"),
			)
			.addTo(this.map);

		this.map.invalidateSize(true);

		const icon = L.icon({
			iconUrl: this.argsValue.iconUrl,
			shadowUrl: this.argsValue.shadowUrl,
			iconSize: [46, 43],
			shadowSize: [46, 43],
			iconAnchor: [17, 43],
			shadowAnchor: [17, 43],
		});

		const center = this._pin ?? this.argsValue.center;
		this.map.setView(center, this.argsValue.zoom);

		this.marker = L.marker(center, { draggable: true, icon });
		this.marker.on("dragend", () =>
			this._writePosition(this.marker.getLatLng()),
		);
		this.marker.addTo(this.map);

		// Clicking the map moves the pin there
		this.map.on("click", (e) => {
			this._setPin([e.latlng.lat, e.latlng.lng]);
		});
	}

	// Moves the pin and writes the new coordinates into the form inputs
	_setPin(position) {
		this._pin = position;
		if (this.marker) {
			this.marker.setLatLng(position);
			this.map.panTo(position);
		}
		this._writePosition({ lat: position[0], lng: position[1] });
	}

	_writePosition({ lat, lng }) {
		// 7 decimal places is ~1cm, tidier than the full float drag precision
		if (this.hasLatitudeTarget)
			this.latitudeTarget.value = Number(lat).toFixed(7);
		if (this.hasLongitudeTarget)
			this.longitudeTarget.value = Number(lng).toFixed(7);
	}

	// Asks the server for the best-guess pin for the current address fields
	async _lookupAddress() {
		const postcode = this._field("postcode")?.value?.trim();
		if (!postcode) return;

		const params = new URLSearchParams({ postcode });
		const street = this._field("street_address")?.value?.trim();
		const city = this._field("city")?.value?.trim();
		if (street) params.set("street", street);
		if (city) params.set("city", city);

		let data;
		try {
			const response = await fetch(`${this.argsValue.lookupUrl}?${params}`, {
				headers: { Accept: "application/json" },
			});
			data = await response.json();
			if (!response.ok) return; // leave the pin; save-time validation reports the bad postcode
		} catch {
			return;
		}

		if (typeof data.latitude !== "number" || typeof data.longitude !== "number")
			return;
		this._setPin([data.latitude, data.longitude]);
	}

	// Address inputs are found by the end of their name so the controller works
	// with any form object name, e.g. [name$="[postcode]"]. They're siblings of
	// this controller's element, so search the enclosing form, not the element.
	_field(name) {
		const scope = this.element.closest("form") || this.element;
		return scope.querySelector(`[name$="[${name}]"]`);
	}
}
