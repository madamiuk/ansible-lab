package pl.ansible.lab;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.SequenceGenerator;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.time.OffsetDateTime;

@Entity
@Table(name = "app_data")
public class AppData {

@Id
@GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "app_data_id_seq")
@SequenceGenerator(
        name = "app_data_id_seq",
        sequenceName = "app_data_id_seq",
        allocationSize = 1
)

@Column(name = "id")
private Long id;
    @Column(name = "hostname")
    private String hostname;

    @Column(name = "created_at")
    private OffsetDateTime createdAt;

    public AppData(String hostname, OffsetDateTime createdAt) {
        this.hostname = hostname;
        this.createdAt = createdAt;
    }

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
