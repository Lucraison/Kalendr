using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Kalendr.API.Migrations
{
    /// <inheritdoc />
    public partial class AddIsAllDay : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "IsAllDay",
                table: "Events",
                type: "INTEGER",
                nullable: false,
                defaultValue: false);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "IsAllDay",
                table: "Events");
        }
    }
}
