# Home Assistant Configuration

Auto-apply when working in `home-assistant/` directory or on HA-related files.

## Dashboard Workflow

Dashboards use **YAML mode** (not UI storage). Edit files directly, then run `update` to deploy.

```bash
hass-cli state list                    # List all entities
hass-cli state get <entity_id>         # Get entity details
hass-cli service call <service>        # Call a service
```

Token: `~/.config/home-assistant/token`

## Bubble Cards Patterns

All cards use `custom:bubble-card`. Common patterns:

### Light Slider Button
```yaml
type: custom:bubble-card
card_type: button
button_type: slider
entity: light.room_name
name: Room Name
icon: mdi:lamp
show_state: true
show_attribute: true
attribute: brightness
slider_live_update: true
allow_light_slider_to_0: false
card_layout: large
```

### Sub-Buttons with Conditional Styling
```yaml
sub_button:
- entity: binary_sensor.door
  show_background: true
  styles: |-
    .bubble-sub-button {
      {% if is_state('binary_sensor.door', 'on') %}
        background-color: rgba(239, 83, 80, 0.3) !important;
      {% else %}
        background-color: rgba(76, 175, 80, 0.3) !important;
      {% endif %}
    }
```

### Popup Navigation
```yaml
- icon: mdi:dots-horizontal
  show_background: true
  tap_action:
    action: fire-dom-event
    browser_mod:
      service: browser_mod.popup
      data:
        title: Room Name
        content: !include ../../popup-content/room.yaml
```

### Popup Base Settings
```yaml
card_type: pop-up
back_open: false
close_by_clicking_outside: true
bg_opacity: '88'
bg_blur: '14'
width_desktop: 540px
auto_close: 60000
show_header: true
```

## YAML Anchors

Use anchors in `cards/templates.yaml` for reusable patterns:
- `&door_sensor_styles` - Red/green conditional door status
- `&water_sensor_styles` - Leak sensor with pulse animation
- `&light_slider_options` - Standard light slider config
- `&popup_base` - Common popup settings

## Directory Structure

```
home-assistant/dashboards/
├── ui-lovelace.yaml       # Main dashboard
├── views/                 # Dashboard views
│   ├── overview-cards/    # Room cards
│   └── sections/          # Section cards
├── popups/                # Popup definitions
├── popup-content/         # Popup card content
└── cards/templates.yaml   # YAML anchors
```
