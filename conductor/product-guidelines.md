# Product Guidelines - CWatch

## Visual Identity
- **Refined Material Aesthetics:** Leverage the core principles of Material Design (clean layouts, consistent hierarchy) but diverge from the "default" look.
    - **Reduced Margins & Rounding:** Avoid excessive padding and heavy corner radii. Aim for a tighter, more professional look suitable for desktop and power-user interfaces.
    - **Subtle Separation:** Use slight background color shifts (surface tonal variations) rather than heavy drop shadows or borders to define sections and panels.
    - **Smoothness:** Prioritize fluid transitions and meaningful animations that don't distract from the data.
- **Iconography Strategy:**
    - **Tech-Centric First:** Supplement standard Material icons with Nerd Fonts to accurately represent technical concepts (Docker containers, servers, specific file types, etc.).
    - **Consistent Weight:** Ensure custom icons blend visually with the standard system icons in terms of stroke width and size.

## User Experience (UX) Principles
- **Adaptive Interaction Model:**
    - **Platform-Aware Controls:** Segregate logic to optimize input methods per platform.
        - *Desktop:* Prioritize keyboard shortcuts and mouse-based context menus.
        - *Touch/Mobile:* Emphasize gesture-based navigation and touch-friendly targets.
    - **Cross-Platform Consistency:** While inputs differ, the visual outcome and state changes must remain consistent across all devices.
- **High Information Density:** Design for power users who need to monitor multiple metrics simultaneously. Use collapsible panels and split views to maximize screen real estate without overwhelming the user.
- **Contextual Power:** Keep the primary UI clean by burying advanced actions in context-sensitive menus (right-click) and toolbars that appear only when relevant (e.g., when a specific container is selected).

## Tone & Voice
- **Professional & Direct:** Use clear, concise language. Avoid jargon where simple terms suffice, but strictly use correct technical terminology for infrastructure concepts.
- **Reliable & Precise:** Error messages and status updates should be specific and actionable.
