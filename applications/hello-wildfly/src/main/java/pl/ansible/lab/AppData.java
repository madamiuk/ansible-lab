package pl.ansible.lab;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.time.OffsetDateTime;

@Entity
@Table(name = "app_data")
public class AppData {

    @Id
    @Column(name = "id")
    private Long id;

    @Column(name = "hostname")
    private String hostname;

    @Column(name = "created_at")
    private OffsetDateTime createdAt;

    public AppData() {
    }

    public Long getId() {
        return id;
    }

    public String getHostname() {
        return hostname;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }
}
