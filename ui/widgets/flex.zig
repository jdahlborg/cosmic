const graphics = @import("graphics");
const Color = graphics.Color;

const ui = @import("../ui.zig");

/// Lays out children vertically.
pub const Column = struct {
    const Self = @This();

    props: struct {
        bg_color: ?Color = null,
        flex: u32 = 1,

        spacing: f32 = 0,

        /// Whether the columns's height will shrink to the total height of it's children or expand to the parent container's height.
        /// Expands to the parent container's height by default.
        expand: bool = true,

        children: ui.FrameListPtr = ui.FrameListPtr.init(0, 0),
    },

    pub fn build(self: *Self, comptime C: ui.Config, c: *C.Build()) ui.FrameId {
        _ = self;
        return c.fragment(self.props.children);
    }

    pub fn layout(self: *Self, comptime C: ui.Config, c: *C.Layout()) ui.LayoutSize {
        _ = self;
        const cstr = c.getSizeConstraint();
        var vacant_size = cstr;
        var cur_y: f32 = 0;
        var max_child_width: f32 = 0;

        const ColumnId = comptime ui.Module(C).WidgetIdByType(Column);
        const GrowId = comptime ui.Module(C).WidgetIdByType(Grow);

        const total_spacing = if (c.node.children.items.len > 0) self.props.spacing * @intToFloat(f32, c.node.children.items.len-1) else 0;
        vacant_size.height -= total_spacing;

        // First pass computes non expanding children.
        var has_expanding_children = false;
        var flex_sum: u32 = 0;
        for (c.node.children.items) |it| {
            switch (it.type_id) {
                ColumnId => {
                    const col = it.getWidget(Column);
                    has_expanding_children = true;
                    flex_sum += col.props.flex;
                    continue;
                },
                GrowId => {
                    const grow = it.getWidget(Grow);
                    has_expanding_children = true;
                    flex_sum += grow.props.flex;
                    continue;
                },
                else => {},
            }
            var child_size = c.computeLayout(it, vacant_size);
            child_size.cropTo(vacant_size);
            c.setLayout(it, ui.Layout.init(0, cur_y, child_size.width, child_size.height));
            cur_y += child_size.height + self.props.spacing;
            vacant_size.height -= child_size.height;
            if (child_size.width > max_child_width) {
                max_child_width = child_size.width;
            }
        }

        if (has_expanding_children) {
            cur_y = 0;
            const flex_unit_size = vacant_size.height / @intToFloat(f32, flex_sum);

            var max_child_size = ui.LayoutSize.init(vacant_size.width, 0);
            for (c.node.children.items) |it| {
                var flex: u32 = undefined;
                switch (it.type_id) {
                    ColumnId => {
                        flex = it.getWidget(Column).props.flex;
                    },
                    GrowId => {
                        flex = it.getWidget(Grow).props.flex;
                    },
                    else => {
                        // Update the layout pos of sized children since this pass will include expanded children.
                        c.setLayoutPos(it, 0, cur_y);
                        cur_y += c.getLayout(it).height;
                        continue;
                    },
                }

                max_child_size.height = flex_unit_size * @intToFloat(f32, flex);
                var child_size = c.computeLayoutStretch(it, max_child_size, false, true);
                child_size.cropTo(max_child_size);
                c.setLayout(it, ui.Layout.init(0, cur_y, child_size.width, child_size.height));
                cur_y += child_size.height + self.props.spacing;
                if (child_size.width > max_child_width) {
                    max_child_width = child_size.width;
                }
            }
        }

        if (self.props.expand) {
            return ui.LayoutSize.init(max_child_width, cstr.height);
        } else {
            if (c.node.children.items.len > 0) {
                return ui.LayoutSize.init(max_child_width, cur_y - self.props.spacing);
            } else {
                return ui.LayoutSize.init(max_child_width, cur_y);
            }
        }
    }

    pub fn render(self: *Self, ctx: *ui.RenderContext) void {
        _ = self;
        _ = ctx;
        // const g = c.g;
        // const n = c.node;

        const props = self.props;

        if (props.bg_color != null) {
            // g.setFillColor(props.bg_color.?);
            // g.fillRect(n.layout.x, n.layout.y, n.layout.width, n.layout.height);
        }
        // TODO: draw border
    }
};

pub const Row = struct {
    const Self = @This();

    props: struct {
        bg_color: ?Color = null,
        flex: u32 = 1,

        spacing: f32 = 0,

        /// Whether the row's width will shrink to the total width of it's children or expand to the parent container's width.
        /// Expands to the parent container's width by default.
        expand: bool = true,

        children: ui.FrameListPtr = ui.FrameListPtr.init(0, 0),
    },

    pub fn build(self: *Self, comptime C: ui.Config, c: *C.Build()) ui.FrameId {
        _ = self;
        return c.fragment(self.props.children);
    }

    pub fn layout(self: *Self, comptime C: ui.Config, c: *C.Layout()) ui.LayoutSize {
        _ = self;
        const cstr = c.getSizeConstraint();
        var vacant_size = cstr;
        var cur_x: f32 = 0;
        var max_child_height: f32 = 0;

        const RowId = comptime ui.Module(C).WidgetIdByType(Row);
        const GrowId = comptime ui.Module(C).WidgetIdByType(Grow);

        const total_spacing = if (c.node.children.items.len > 0) self.props.spacing * @intToFloat(f32, c.node.children.items.len-1) else 0;
        vacant_size.width -= total_spacing;

        // First pass computes non expanding children.
        var has_expanding_children = false;
        var flex_sum: u32 = 0;
        for (c.node.children.items) |it| {
            switch (it.type_id) {
                RowId => {
                    const row = it.getWidget(Row);
                    has_expanding_children = true;
                    flex_sum += row.props.flex;
                    continue;
                },
                GrowId => {
                    const grow = it.getWidget(Grow);
                    has_expanding_children = true;
                    flex_sum += grow.props.flex;
                    continue;
                },
                else => {},
            }
            var child_size = c.computeLayout(it, vacant_size);
            child_size.cropTo(vacant_size);
            c.setLayout(it, ui.Layout.init(cur_x, 0, child_size.width, child_size.height));
            cur_x += child_size.width + self.props.spacing;
            vacant_size.width -= child_size.width;
            if (child_size.height > max_child_height) {
                max_child_height = child_size.height;
            }
        }

        if (has_expanding_children) {
            cur_x = 0;
            const flex_unit_size = vacant_size.width / @intToFloat(f32, flex_sum);

            var max_child_size = ui.LayoutSize.init(0, vacant_size.height);
            for (c.node.children.items) |it| {
                var flex: u32 = undefined;
                switch (it.type_id) {
                    RowId => {
                        flex = it.getWidget(Row).props.flex;
                    },
                    GrowId => {
                        flex = it.getWidget(Grow).props.flex;
                    },
                    else => {
                        // Update the layout pos of sized children since this pass will include expanded children.
                        c.setLayoutPos(it, cur_x, 0);
                        cur_x += c.getLayout(it).width;
                        continue;
                    },
                }

                max_child_size.width = flex_unit_size * @intToFloat(f32, flex);
                var child_size = c.computeLayoutStretch(it, max_child_size, true, false);
                child_size.cropTo(max_child_size);
                c.setLayout(it, ui.Layout.init(cur_x, 0, child_size.width, child_size.height));
                cur_x += child_size.width + self.props.spacing;
                if (child_size.height > max_child_height) {
                    max_child_height = child_size.height;
                }
            }
        }

        if (self.props.expand) {
            return ui.LayoutSize.init(cstr.width, max_child_height);
        } else {
            if (c.node.children.items.len > 0) {
                return ui.LayoutSize.init(cur_x - self.props.spacing, max_child_height);
            } else {
                return ui.LayoutSize.init(cur_x, max_child_height);
            }
        }
    }

    pub fn render(self: *Self, c: *ui.RenderContext) void {
        _ = self;
        const g = c.g;
        const alo = c.getAbsLayout();

        const props = self.props;

        if (props.bg_color != null) {
            g.setFillColor(props.bg_color.?);
            g.fillRect(alo.x, alo.y, alo.width, alo.height);
        }
        // TODO: draw border
    }
};

/// Grows a child widget's width, or height, or both depending on parent's preference.
/// Exposes a flex property for the parent which can be used or ignored.
pub const Grow = struct {
    const Self = @This();

    props: struct {
        child: ui.FrameId = ui.NullFrameId,
        flex: u32 = 1,

        /// By default, Grow will consider the parent prefs to determine which axis to grow.
        /// These will override those prefs.
        grow_width: ?bool = null,
        grow_height: ?bool = null,
    },

    pub fn init(self: *Self, comptime C: ui.Config, c: *C.Init()) void {
        _ = c;
        _ = self;
    }

    pub fn build(self: *Self, comptime C: ui.Config, c: *C.Build()) ui.FrameId {
        _ = c;
        return self.props.child;
    }

    /// Computes the child layout preferring to stretch it and returns the current constraint.
    pub fn layout(self: *Self, comptime C: ui.Config, c: *C.Layout()) ui.LayoutSize {
        _ = self;
        const cstr = c.getSizeConstraint();
        const node = c.getNode();

        var prefer_exact_width = self.props.grow_width orelse c.prefer_exact_width;
        var prefer_exact_height = self.props.grow_height orelse c.prefer_exact_height;

        if (node.children.items.len == 0) {
            var res = ui.LayoutSize.init(0, 0);
            if (prefer_exact_width) {
                res.width = cstr.width;
            }
            if (prefer_exact_height) {
                res.height = cstr.height;
            }
            return res;
        }

        const child = node.children.items[0];
        const child_size = c.computeLayoutStretch(child, cstr, prefer_exact_width, prefer_exact_height);
        var res = child_size;
        if (prefer_exact_width) {
            res.width = cstr.width;
        }
        if (prefer_exact_height) {
            res.height = cstr.height;
        }
        c.setLayout(child, ui.Layout.init(0, 0, child_size.width, child_size.height));
        return res;
    }
};