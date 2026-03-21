using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Kalendr.API.Migrations
{
    /// <inheritdoc />
    public partial class AddEventColorAndSharing : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "Color",
                table: "Events",
                type: "TEXT",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "EventGroupShares",
                columns: table => new
                {
                    EventId = table.Column<Guid>(type: "TEXT", nullable: false),
                    GroupId = table.Column<Guid>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_EventGroupShares", x => new { x.EventId, x.GroupId });
                    table.ForeignKey(
                        name: "FK_EventGroupShares_Events_EventId",
                        column: x => x.EventId,
                        principalTable: "Events",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_EventGroupShares_Groups_GroupId",
                        column: x => x.GroupId,
                        principalTable: "Groups",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_EventGroupShares_GroupId",
                table: "EventGroupShares",
                column: "GroupId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "EventGroupShares");

            migrationBuilder.DropColumn(
                name: "Color",
                table: "Events");
        }
    }
}
