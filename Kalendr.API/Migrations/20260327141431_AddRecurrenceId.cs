using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Kalendr.API.Migrations
{
    /// <inheritdoc />
    public partial class AddRecurrenceId : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "RecurrenceId",
                table: "Events",
                type: "TEXT",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "RecurrenceId",
                table: "Events");
        }
    }
}
